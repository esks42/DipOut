//
//  ReceiptParser.swift
//  TIP CALCULATOR
//
//  Turns raw OCR text into a ReceiptData. Pure string work — testable with canned text.
//
//  Real phone-photo OCR (see ReceiptParserRealWorldTests) is messy: receipts are two-column,
//  often two copies in one frame, with currency symbols, decimal-comma slips, and tip
//  suggestions split across lines. The parser is built around a few robust ideas:
//
//   • Summary (subtotal/tax/total): trust the *earliest* run of three standalone amounts that
//     satisfies subtotal + tax = total with a plausible tax rate. This skips item blocks and the
//     "Amount / + Tip / = Total" payment block (whose tax slot is really the tip), and ignores
//     duplicate copies after the first.
//   • Tip suggestions: same-line first, tolerating noise between "%" and the amount; if the
//     receipt prints them in a column (a block of "N%" then a block of "$x"), zip the two blocks.
//   • Auto-gratuity receipts: when a "Auto Gratuity / Service Charge" line carries a value the
//     printed total already includes it, so any "+N%" suggestions are *additional* tips, not the
//     basis — they're dropped and the gratuity is captured separately.
//

import Foundation

nonisolated enum ReceiptParser {

    /// Sales tax is never a large fraction of the subtotal; this rejects "two items that happen
    /// to sum to a third" and the tip slot of a payment block from being read as (subtotal,tax,total).
    private static let maxTaxRate = 0.30

    static func parse(_ text: String) -> ReceiptData {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        let merchantName = extractMerchantName(from: lines)
        let symbol = currencySymbol(in: text)

        // Lines from a "Suggested *Additional* Tip" section onward are add-on tips, not the basis.
        let additionalCutoff = lines.firstIndex { $0.lowercased().contains("additional tip") } ?? lines.count

        // Find the start of the suggested tips section
        let suggestionsStart = lines.prefix(additionalCutoff).firstIndex { l in
            let s = l.lowercased()
            return !s.contains("additional")
                && (s.contains("suggested tip") || s.contains("suggested gratuity")
                    || s.contains("gratuity calculation") || s.contains("tip guide")
                    || s.firstMatch(of: #/suggested\s+gratuity/#) != nil
                    || s.firstMatch(of: #/suggested\s+tip/#) != nil)
        }
        let gratuityCutoff = suggestionsStart ?? additionalCutoff

        // 1. Tip suggestions — same-line first.
        var tips: [SuggestedTip] = []
        for (i, line) in lines.enumerated() where i < additionalCutoff {
            tips.append(contentsOf: tipSuggestions(in: line))
        }
        // …falling back to a column layout (a block of "N%" then a block of "$x") if sparse.
        if tips.count < 2, hasTipHeader(lines, before: additionalCutoff) {
            for t in columnTips(lines, before: additionalCutoff) where !tips.contains(t) { tips.append(t) }
        }

        // 2. Standalone amounts, in reading order, drive summary inference.
        let amounts = lines.compactMap { Self.standaloneAmount(in: $0) }

        var subtotal: Double?, tax: Double?, total: Double?
        var gratuity: SuggestedTip?

        // 2a. Same-line labelled values (clean single-column receipts). Only true currency amounts
        //     count (so "VAT @ 23%" isn't read as a $23 tax), and we keep every grand-total
        //     candidate so an auto-gratuity total can be picked over the pre-gratuity subtotal.
        var totalCandidates: [Double] = []
        for (i, line) in lines.enumerated() where i < additionalCutoff {
            guard let v = labeledAmount(in: line) else { continue }
            let lower = line.lowercased()
            // A real tax line carries an amount, not a rate — "Base 33,98 TAX 23%" (with a "%" or a
            // "base"/"ex" qualifier) is a VAT breakdown, never the tax total.
            let isTaxAmount = (lower.contains("tax") || lower.contains("vat"))
                && !lower.contains("base") && !lower.contains("ex ") && !lower.contains("%")
            if lower.contains("subtotal")    { subtotal = subtotal ?? v }
            else if isTaxAmount              { tax = tax ?? v }
            else if isGrandTotalLabel(lower) { total = total ?? v; totalCandidates.append(v) }
        }

        // 2b. Earliest plausible subtotal+tax=total triple (column receipts, multi-copy frames).
        if !(subtotal != nil && tax != nil && total != nil), let t = earliestTriple(amounts) {
            subtotal = subtotal ?? t.subtotal; tax = tax ?? t.tax; total = total ?? t.total
        }

        // 2c. Label-block ↔ value-block zip — needed for auto-gratuity receipts whose total
        //     (subtotal + gratuity + tax + fees) never satisfies the simple triple.
        if subtotal == nil || total == nil || hasGratuityLabel(lines) {
            if let z = blockZip(lines) {
                subtotal = subtotal ?? z.subtotal
                tax = tax ?? z.tax
                total = total ?? z.total
                if let zt = z.total { totalCandidates.append(zt) }
                gratuity = gratuity ?? z.gratuity
            }
        }

        // 2d. Gratuity from a "Gratuity 20.00%" / "Service Charge" / "Auto Gratuity" line. We only
        //     count it when a real charged amount backs it up — either printed on the line, or (for
        //     two-column receipts) found among the receipt's numbers as subtotal×% or the
        //     post-gratuity total. So a boilerplate "20% service charge to parties of six+" note
        //     with no matching amount never trips it.
        // A receipt that states the tip is included ("TIPS 10 INCLUDED") turns a "Tip 10%" line into
        // an included gratuity too, not just "Gratuity"/"Service Charge" wording.
        let lowerText = text.lowercased()
        let tipIncluded = lowerText.contains("included") && !lowerText.contains("not included")
        if gratuity == nil {
            for line in lines.prefix(gratuityCutoff)
            where isGratuityLine(line) || (tipIncluded && isTipPercentLine(line)) {
                let p = firstPercent(in: line)
                if let amt = gratuityAmount(in: line) {
                    gratuity = SuggestedTip(percent: p, amount: amt); break
                }
                guard let p, let sub = subtotal, sub > 0 else { continue }
                let charged = sub * p / 100
                let near = { (target: Double) in amounts.first { abs($0 - target) <= max(0.02, target * 0.005) } }
                // Prefer the printed amount; fall back to the computed charge if only the
                // post-gratuity total confirms it.
                if let printed = near(charged) {
                    gratuity = SuggestedTip(percent: p, amount: printed); break
                }
                if near(sub + (tax ?? 0) + charged) != nil {
                    gratuity = SuggestedTip(percent: p, amount: charged); break
                }
            }
        }

        // 2e. Last resort: grand-total lost to OCR — items sum to the subtotal, tax follows.
        if subtotal == nil || tax == nil || total == nil {
            if let s = inferFromItemSum(amounts) {
                subtotal = subtotal ?? s.subtotal
                tax = tax ?? s.tax
                total = total ?? s.total
            }
        }

        // 3. A gratuity already on the bill must be inside the grand total. Build it from the parts
        //    (ignoring a "tax" slot that actually captured the gratuity), and prefer the largest
        //    printed total. Then derive a missing/mis-captured tax from the resolved total so the
        //    gratuity isn't double-counted (e.g. a VAT-inclusive euro bill ends up with tax 0).
        if let g = gratuity {
            let taxIsGratuity = tax != nil && abs((tax ?? 0) - g.amount) < 0.02
            let cleanTax = (tax == nil || taxIsGratuity) ? 0 : (tax ?? 0)
            let parts = (subtotal ?? 0) + cleanTax + g.amount
            total = max(totalCandidates.max() ?? 0, max(parts, total ?? 0))
            if tax == nil || taxIsGratuity {
                tax = max(0, (total ?? 0) - (subtotal ?? 0) - g.amount)
            }
        }

        // 4. Subtotal not printed → derive it so the rest of the app has something to work with.
        var subtotalInferred = false
        if (subtotal ?? 0) <= 0, let tot = total, tot > 0 {
            subtotal = tot - (tax ?? 0)
            subtotalInferred = true
        }

        // 5. An already-included gratuity means printed "tips" are additional — drop them.
        if gratuity != nil { tips.removeAll() }

        return ReceiptData(restaurantName: merchantName, subtotal: subtotal ?? 0, tax: tax ?? 0, total: total ?? 0,
                           suggestedTips: tips, includedGratuity: gratuity,
                           currencySymbol: symbol, subtotalInferred: subtotalInferred)
    }

    // MARK: Currency

    private static func currencySymbol(in text: String) -> String {
        let upper = text.uppercased()
        if text.contains("€") || upper.contains("EUR") { return "€" }
        if text.contains("£") || upper.contains("GBP") { return "£" }
        if text.contains("¥") || upper.contains("JPY") { return "¥" }
        return "$"
    }

    // MARK: Amount parsing

    /// Parse a currency token tolerating thousands separators and decimal-comma OCR slips
    /// ("$1,250.00" → 1250.0, "$34,50" → 34.5).
    private static func amountValue(_ raw: String) -> Double? {
        var t = raw.filter { $0.isNumber || $0 == "." || $0 == "," }
        if let m = t.wholeMatch(of: /\d+,\d{2}/) {           // decimal comma
            t = String(m.0).replacingOccurrences(of: ",", with: ".")
        } else {
            t = t.replacingOccurrences(of: ",", with: "")    // thousands separators
        }
        return Double(t)
    }

    /// A line that is *only* a currency amount (e.g. "$28.50", "€14.00", "฿187.81", "133,49 EUR"),
    /// tolerating a single leading currency symbol/OCR glyph and an optional trailing currency code.
    /// Requires two decimal places.
    private static func standaloneAmount(in line: String) -> Double? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let m = trimmed.wholeMatch(of: #/[^\d\s]?\s*([\d,]+[.,]\d{2})(?:\s+[A-Za-z]{2,3})?/#) else { return nil }
        return amountValue(String(m.1))
    }

    /// Last *currency amount* (two decimals) on a line, for same-line "SUBTOTAL  45.00" layouts.
    /// Bare integers like the "23" in "VAT @ 23%" are intentionally ignored.
    private static func labeledAmount(in line: String) -> Double? {
        guard let last = line.matches(of: #/[\d,]+[.,]\d{2}/#).last else { return nil }
        return amountValue(String(last.0))
    }

    /// The charged amount on a gratuity line, ignoring the rate token ("Gratuity 20.00% 104.00" → 104.00).
    private static func gratuityAmount(in line: String) -> Double? {
        let withoutRate = line.replacing(#/\d{1,2}(?:\.\d+)?\s*%/#, with: " ")
        return labeledAmount(in: withoutRate)
    }

    private static func isGratuityLine(_ line: String) -> Bool {
        let s = line.lowercased()
        return s.contains("auto gratuity") || s.contains("service charge")
            || (s.contains("gratuity") && firstPercent(in: line) != nil)
    }

    /// A "Tip 10%"-style line (a percentage tip), used only when the receipt says the tip is included.
    private static func isTipPercentLine(_ line: String) -> Bool {
        let s = line.lowercased()
        return s.contains("tip") && !s.contains("additional") && firstPercent(in: line) != nil
    }

    // MARK: Tip suggestions

    /// All "percent + amount" pairs on a line, tolerating a short run of noise (OCR'd "is"/"="/"$"
    /// /parens) between the "%" and the amount.
    private static func tipSuggestions(in line: String) -> [SuggestedTip] {
        line.matches(of: #/(\d{1,2}(?:\.\d+)?)\s*%.{0,30}?([\d,]+[.,]\d{2})/#).compactMap { m in
            guard let amount = amountValue(String(m.2)) else { return nil }
            return SuggestedTip(percent: Double(String(m.1)), amount: amount)
        }
    }

    private static func hasTipHeader(_ lines: [String], before cutoff: Int) -> Bool {
        lines.prefix(cutoff).contains { l in
            let s = l.lowercased()
            return !s.contains("additional")
                && (s.contains("suggested tip") || s.contains("suggested gratuity")
                    || s.contains("gratuity calculation") || s.contains("tip guide"))
        }
    }

    /// When a receipt prints a column of percentages and another column of amounts, or heavily interleaved noise.
    /// We grab all standalone percents and standalone amounts, and zip them intelligently.
    private static func columnTips(_ lines: [String], before cutoff: Int) -> [SuggestedTip] {
        guard var start = lines.prefix(cutoff).firstIndex(where: { l in
            let s = l.lowercased()
            return !s.contains("additional")
                && (s.contains("suggested tip") || s.contains("suggested gratuity")
                    || s.contains("gratuity calculation")
                    || s.firstMatch(of: #/suggested\s+gratuity/#) != nil
                    || s.firstMatch(of: #/suggested\s+tip/#) != nil)
        }) else { return [] }

        // Scan backwards to find the true beginning of the tip column block
        // (e.g. if percentages are printed above the header due to OCR column-interleaving)
        var scanStart = start
        while scanStart > 0 {
            let prevLine = lines[scanStart - 1]
            let lowerPrev = prevLine.lowercased()
            
            // Stop if we hit a total/subtotal/item line
            if lowerPrev.contains("total") || lowerPrev.contains("subtotal") || lowerPrev.contains("balance") || lowerPrev.contains("tax") {
                break
            }
            
            // Keep moving up if the line contains a percent or is part of the tip block
            if prevLine.contains("%") || lowerPrev.contains("sale") || lowerPrev.contains("suggested") || prevLine.trimmingCharacters(in: .whitespaces) == "%" {
                scanStart -= 1
            } else {
                break
            }
        }
        start = scanStart

        var tips: [SuggestedTip] = []
        var pendingPercents: [Double] = []
        var pendingAmounts: [Double] = []
        
        for line in lines[start..<cutoff] {
            let pMatches = line.matches(of: #/(?:\b|^)(\d{1,2}(?:[.,]\d+)?)\s*%/#)
            
            // Remove matched percents from the line before extracting amounts
            var lineForAmounts = line
            for pm in pMatches {
                lineForAmounts = lineForAmounts.replacing(pm.0, with: " ")
            }
            let aMatches = lineForAmounts.matches(of: #/([\d,]+[.,]\d{2})/#)
            
            if !pMatches.isEmpty && pendingPercents.isEmpty {
                // Starting a new percent block, clear any accumulated garbage amounts
                pendingAmounts.removeAll()
            }
            
            for m in pMatches {
                let pStr = String(m.1).replacingOccurrences(of: ",", with: ".")
                let p = Double(pStr) ?? 0
                if !pendingPercents.contains(p) { pendingPercents.append(p) }
            }
            
            for m in aMatches {
                if let a = amountValue(String(m.1)) {
                    pendingAmounts.append(a)
                }
            }
            
            if !pendingPercents.isEmpty && !pendingAmounts.isEmpty {
                let limit = min(pendingPercents.count, pendingAmounts.count)
                for i in 0..<limit {
                    tips.append(SuggestedTip(percent: pendingPercents[i], amount: pendingAmounts[i]))
                }
                pendingPercents.removeFirst(limit)
                pendingAmounts.removeAll() // Clear amounts so trailing totals are ignored
            }
        }
        return tips
    }

    // MARK: Summary inference

    private static func isTotalLabel(_ lower: String) -> Bool {
        guard !lower.contains("subtotal") else { return false }
        if lower.contains("suggested") || lower.contains("gratuity") || lower.contains("tip") {
            return false
        }
        return lower.contains("total") || lower.contains("balance due")
            || lower.contains("amount due") || lower.contains("total due")
    }

    /// Like `isTotalLabel` but also accepts a bare "Amount" grand total (excluding "Amount Paid"
    /// and the card's "Transaction Amount", which on a foreign card is a converted duplicate).
    private static func isGrandTotalLabel(_ lower: String) -> Bool {
        if lower.contains("amount paid") || lower.contains("transaction") { return false }
        return isTotalLabel(lower) || lower.contains("amount")
    }

    /// First three consecutive standalone amounts that read as subtotal, tax, total with a
    /// believable tax rate. Skips item blocks (no clean sum) and the tip slot of a payment block.
    private static func earliestTriple(_ a: [Double]) -> (subtotal: Double, tax: Double, total: Double)? {
        guard a.count >= 3 else { return nil }
        for i in 0...(a.count - 3) {
            let (sub, tx, tot) = (a[i], a[i + 1], a[i + 2])
            if sub > 0, tx > 0, tx / sub <= maxTaxRate, abs(sub + tx - tot) <= 0.02 {
                return (sub, tx, tot)
            }
        }
        return nil
    }

    private static func hasGratuityLabel(_ lines: [String]) -> Bool {
        lines.contains { l in
            let s = l.lowercased()
            // "auto gratuity" is unambiguous; a bare "service charge"/"gratuity" only counts when
            // it carries a percentage (so "service charge not included" doesn't trip it).
            return s.contains("auto gratuity")
                || ((s.contains("service charge") || s.contains("gratuity")) && firstPercent(in: l) != nil)
        }
    }

    private enum Field { case subtotal, tax, total, gratuity, skip }

    private static func summaryField(_ line: String) -> Field? {
        let s = line.lowercased()
        if Self.standaloneAmount(in: line) != nil { return nil }          // it's a value, not a label
        if s.contains("auto gratuity") || s.contains("service charge") { return .gratuity }
        if s.contains("amount paid") || s.contains("service fee") || s.contains("optional") { return .skip }
        if s.contains("subtotal")                       { return .subtotal }
        if s.contains("tax") || s.contains("vat")       { return .tax }
        if s.contains("amount") || isTotalLabel(s)      { return .total }
        return .skip
    }

    /// Match a summary's *labels* to its *values* by position. Vision lists both columns top to
    /// bottom but often interleaves them (a stray "$569.40" between two label lines), so we gather a
    /// region of consecutive label/value lines and zip the two sequences in order. The only reliable
    /// read for auto-gratuity receipts, whose total never satisfies the simple subtotal+tax=total.
    private static func blockZip(_ lines: [String]) -> (subtotal: Double?, tax: Double?, total: Double?, gratuity: SuggestedTip?)? {
        var i = 0
        while i < lines.count {
            let firstField = summaryField(lines[i])
            guard firstField != nil && firstField != .skip else { i += 1; continue }   // region starts at a primary label

            var labels: [(Field, String)] = []
            var values: [Double] = []
            var j = i
            while j < lines.count {
                let trimmed = lines[j].trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = lines[j].lowercased()
                
                let isTipPercentHeader = trimmed == "%" || lower.contains("of sale") || lower.contains("sale:")
                let isTipKeyword = lower.contains("gratuity") || lower.contains("tip") || lower.contains("suggested")
                let isEndKeyword = lower.contains("pleasure") || lower.contains("thank") || lower.contains("visa") 
                    || lower.contains("mastercard") || lower.contains("amex") || lower.contains("card") || lower.contains("payment")
                
                if isTipPercentHeader || isTipKeyword || isEndKeyword {
                    break
                }

                if let f = summaryField(lines[j]) { labels.append((f, lines[j])) }
                else if let v = Self.standaloneAmount(in: lines[j]) { values.append(v) }
                j += 1
            }

            let hasSummary = labels.contains { $0.0 == .total || $0.0 == .gratuity }
                && labels.contains { $0.0 == .subtotal || $0.0 == .total }
            if labels.count >= 2, labels.count == values.count, hasSummary {
                var sub: Double?, tx: Double?, tot: Double?, grat: SuggestedTip?
                for (idx, label) in labels.enumerated() {
                    switch label.0 {
                    case .subtotal: sub = values[idx]
                    case .tax:      tx = values[idx]
                    case .total:    tot = values[idx]
                    case .gratuity: grat = SuggestedTip(percent: firstPercent(in: label.1), amount: values[idx])
                    case .skip:     break
                    }
                }
                if sub != nil || tot != nil { return (sub, tx, tot, grat) }
            }
            i += 1
        }
        return nil
    }

    private static func firstPercent(in line: String) -> Double? {
        line.firstMatch(of: #/(\d{1,2}(?:\.\d+)?)\s*%/#).map { Double(String($0.1)) ?? 0 }
    }

    private static func extractMerchantName(from lines: [String]) -> String {
        // First look for a "Welcome to [Name]" line
        for line in lines.prefix(10) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            if lower.hasPrefix("welcome to") {
                let namePart = trimmed.dropFirst(10).trimmingCharacters(in: .whitespacesAndNewlines)
                var cleanName = namePart
                while cleanName.hasSuffix("!") || cleanName.hasSuffix(".") {
                    cleanName.removeLast()
                }
                if !cleanName.isEmpty {
                    return cleanName
                }
            }
        }
        
        func isGarbage(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return true }
            
            // Exclude single percentage like "100%" or "99%"
            if trimmed.wholeMatch(of: #/\d{1,3}\s*%/#) != nil { return true }
            
            // Exclude times like "12:00 PM", "9:41"
            if trimmed.firstMatch(of: #/\b\d{1,2}:\d{2}(?:\s*(?:[AaPp][Mm]))?\b/#) != nil { return true }
            
            // Exclude dates like "3/11/26", "2026-06-09"
            if trimmed.firstMatch(of: #/\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b/#) != nil
                || trimmed.firstMatch(of: #/\b\d{4}[-/]\d{1,2}[-/]\d{1,2}\b/#) != nil { return true }
            
            // Exclude short garbage like "LTE", "5G", "AM", "PM", "4G"
            if trimmed.count <= 4 {
                let lower = trimmed.lowercased()
                if lower == "lte" || lower == "5g" || lower == "4g" || lower == "am" || lower == "pm" {
                    return true
                }
                if trimmed.rangeOfCharacter(from: CharacterSet.letters) == nil {
                    return true
                }
            }
            
            // Exclude lines with only digits/symbols/dates
            if trimmed.rangeOfCharacter(from: CharacterSet.letters) == nil {
                return true
            }
            
            let lower = trimmed.lowercased()
            if lower.hasPrefix("order#") || lower.hasPrefix("order ") || lower.hasPrefix("server:") || lower.hasPrefix("table:")
                || lower.hasPrefix("date:") || lower.hasPrefix("time:") || lower.hasPrefix("check:") || lower.hasPrefix("guest:")
                || lower.hasPrefix("guests:") || lower.hasPrefix("cashier:") || lower.hasPrefix("terminal:")
                || lower.hasPrefix("receipt") || lower.hasPrefix("transaction") || lower.hasPrefix("merchant id")
                || lower.hasPrefix("tel:") || lower.hasPrefix("phone:") || lower.hasPrefix("store:")
            {
                return true
            }
            
            return false
        }
        
        for line in lines.prefix(10) {
            if !isGarbage(line) {
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "Unknown"
    }

    /// Grand-total line lost to OCR: an amount equals the running sum of the items before it
    /// (= subtotal); the next amount is tax, so total = subtotal + tax. Needs at least two items
    /// summing (so two coincidentally-equal amounts aren't read as subtotal+tax) and a plausible tax.
    private static func inferFromItemSum(_ a: [Double]) -> (subtotal: Double, tax: Double, total: Double)? {
        guard a.count >= 4 else { return nil }
        for k in 2..<(a.count - 1) where abs(a[0..<k].reduce(0, +) - a[k]) <= 0.02 {
            let (sub, tx) = (a[k], a[k + 1])
            guard tx > 0, tx / sub <= maxTaxRate else { continue }
            return (sub, tx, sub + tx)
        }
        return nil
    }
}
