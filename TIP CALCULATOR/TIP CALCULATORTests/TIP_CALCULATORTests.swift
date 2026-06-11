//
//  TIP_CALCULATORTests.swift
//  TIP CALCULATORTests
//
//  Tests for the pure receipt-processing engine.
//

import Testing
import Foundation
@testable import TIP_CALCULATOR

// MARK: - Tip-basis detection

struct TipBasisDetectionTests {

    // subtotal 45.00, tax 3.71 → post-tax base 48.71
    // 20% printed as 9.74 ≈ 48.71×20% (not 45×20%=9.00) → tipping on tax.
    @Test func detectsPostTaxWithStatedPercent() {
        let tip = SuggestedTip(percent: 20, amount: 9.74)
        let r = TipCalculator.detectBasis(for: tip, subtotal: 45.00, tax: 3.71)
        #expect(r.basis == .postTax)
        #expect(r.percent == 20)
        #expect(abs(r.overcharge - 0.742) < 0.001)   // tax × 20%
    }

    // subtotal 50.00, tax 4.00 → 18% printed as 9.00 = 50×18% → fair.
    @Test func detectsPreTaxWithStatedPercent() {
        let tip = SuggestedTip(percent: 18, amount: 9.00)
        let r = TipCalculator.detectBasis(for: tip, subtotal: 50.00, tax: 4.00)
        #expect(r.basis == .preTax)
        #expect(r.percent == 18)
        #expect(r.overcharge == 0)
    }

    // No percent printed: 9.74 / 48.71 = 20.0% (post) vs / 45 = 21.6% (pre) → post-tax 20%.
    @Test func infersPostTaxWhenPercentMissing() {
        let tip = SuggestedTip(percent: nil, amount: 9.74)
        let r = TipCalculator.detectBasis(for: tip, subtotal: 45.00, tax: 3.71)
        #expect(r.basis == .postTax)
        #expect(r.percent == 20)
    }

    // No percent printed: 9.00 / 50 = 18.0% (pre) → pre-tax 18%.
    @Test func infersPreTaxWhenPercentMissing() {
        let tip = SuggestedTip(percent: nil, amount: 9.00)
        let r = TipCalculator.detectBasis(for: tip, subtotal: 50.00, tax: 4.00)
        #expect(r.basis == .preTax)
        #expect(r.percent == 18)
    }

    // An amount that matches no common rate on either base → unknown.
    @Test func returnsUnknownWhenNothingMatches() {
        let tip = SuggestedTip(percent: nil, amount: 6.13)
        let r = TipCalculator.detectBasis(for: tip, subtotal: 50.00, tax: 4.00)
        #expect(r.basis == .unknown)
    }
}

// MARK: - Overall verdict

struct OverallBasisTests {

    @Test func flagsReceiptThatTipsOnTax() {
        let r = ReceiptData(subtotal: 23.85, tax: 2.34, total: 26.19, suggestedTips: [
            SuggestedTip(percent: 15, amount: 3.93),
            SuggestedTip(percent: 18, amount: 4.71),
            SuggestedTip(percent: 20, amount: 5.24),
        ])
        let v = TipCalculator.overallBasis(for: r)
        #expect(v?.basis == .postTax)
        #expect((v?.overcharge ?? 0) > 0)
    }

    @Test func passesFairReceipt() {
        let r = ReceiptData(subtotal: 20, tax: 1.78, total: 21.78,
                            suggestedTips: [SuggestedTip(percent: 20, amount: 4.00)])
        #expect(TipCalculator.overallBasis(for: r)?.basis == .preTax)
    }

    @Test func nilWhenNoSuggestions() {
        let r = ReceiptData(subtotal: 20, tax: 1.78, total: 21.78)
        #expect(TipCalculator.overallBasis(for: r) == nil)
    }
}

// MARK: - Recalculation

struct RecalculationTests {

    @Test func recalculatesTipOnSubtotalExact() {
        #expect(TipCalculator.recalculatedTip(subtotal: 45.00, tax: 3.71, percent: 20) == 9.00)
    }

    @Test func roundUpToDollarRoundsTheNewTotalUp() {
        // 45.00 + 3.71 + 9.00 = 57.71 → total rounds up to 58.00 → tip absorbs the 0.29
        let tip = TipCalculator.recalculatedTip(subtotal: 45.00, tax: 3.71, percent: 20, rounding: .roundUpToDollar)
        #expect(tip == 9.29)
        #expect(TipCalculator.newTotal(subtotal: 45.00, tax: 3.71, tip: tip) == 58.00)
    }

    @Test func roundUpLeavesWholeDollarTotalUnchanged() {
        // 45.00 + 0.00 + 9.00 = 54.00 already whole → tip stays 9.00
        #expect(TipCalculator.recalculatedTip(subtotal: 45.00, tax: 0.00, percent: 20, rounding: .roundUpToDollar) == 9.00)
    }

    @Test func newTotalSumsSubtotalTaxTip() {
        #expect(TipCalculator.newTotal(subtotal: 45.00, tax: 3.71, tip: 9.00) == 57.71)
    }
}

// MARK: - Amount saved

struct AmountSavedTests {

    // Chosen % is printed: saved = printed suggestion − my pre-tax tip.
    @Test func savedAgainstPrintedSuggestion() {
        let r = ReceiptData(subtotal: 45.00, tax: 3.71, total: 48.71,
                            suggestedTips: [SuggestedTip(percent: 20, amount: 9.74)])
        // my 20% pre-tax tip = 9.00
        #expect(TipCalculator.amountSaved(receipt: r, percent: 20, actualTip: 9.00) == 0.74)
    }

    // A receipt with no printed suggestions has no overcharge to compare against → no saving.
    @Test func noSavingWhenReceiptHasNoSuggestions() {
        let r = ReceiptData(subtotal: 45.00, tax: 3.71, total: 48.71)
        #expect(TipCalculator.amountSaved(receipt: r, percent: 10, actualTip: 4.50) == 0)
    }

    // Post-tax receipt, chosen % not printed: compare to that % on the tax-inclusive subtotal.
    @Test func savedAgainstHypotheticalWhenPostTaxAndPercentNotPrinted() {
        let r = ReceiptData(subtotal: 45.00, tax: 3.71, total: 48.71,
                            suggestedTips: [SuggestedTip(percent: 20, amount: 9.74)])  // post-tax
        // 10% of (45.00 + 3.71) = 4.871 → 4.87 vs my 10% pre-tax tip 4.50 → 0.37
        #expect(TipCalculator.amountSaved(receipt: r, percent: 10, actualTip: 4.50) == 0.37)
    }

    // A fair (pre-tax) receipt never shows a saving, even at a non-printed rate.
    @Test func noSavingOnFairReceipt() {
        let r = ReceiptData(subtotal: 50.00, tax: 4.00, total: 54.00,
                            suggestedTips: [SuggestedTip(percent: 18, amount: 9.00)])  // pre-tax
        #expect(TipCalculator.amountSaved(receipt: r, percent: 10, actualTip: 5.00) == 0)
    }

    @Test func neverNegative() {
        let r = ReceiptData(subtotal: 45.00, tax: 3.71, total: 48.71,
                            suggestedTips: [SuggestedTip(percent: 20, amount: 8.00)])
        #expect(TipCalculator.amountSaved(receipt: r, percent: 20, actualTip: 9.00) == 0)
    }
}

// MARK: - Split

struct SplitTests {

    @Test func splitsEvenlyWhenDivisible() {
        let s = TipCalculator.split(tip: 9.00, total: 57.70, people: 2)
        #expect(s.totalShares == [28.85, 28.85])
        #expect(s.perPersonTip == 4.50)
        #expect(s.perPersonTotal == 28.85)
    }

    @Test func reconcilesLeftoverCents() {
        // 57.71 / 3 = 19.236… → 19.24, 19.24, 19.23  (sums to 57.71)
        let s = TipCalculator.split(tip: 9.00, total: 57.71, people: 3)
        #expect(s.totalShares == [19.24, 19.24, 19.23])
        #expect(abs(s.totalShares.reduce(0, +) - 57.71) < 0.0001)
    }
}

// MARK: - Scan-limit trial

struct ScanLimitTrackerTests {

    /// Each test gets an isolated UserDefaults suite so the lifetime counter starts clean.
    private func tracker() -> ScanLimitTracker {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return ScanLimitTracker(defaults: suite)
    }

    @Test func startsWithFullAllowance() {
        let t = tracker()
        #expect(t.scansUsed == 0)
        #expect(t.remainingFreeScans == t.freeScanAllowance)
        #expect(t.hasFreeScans)
    }

    @Test func recordingScansDecrementsRemaining() {
        let t = tracker()
        t.recordScan()
        #expect(t.scansUsed == 1)
        #expect(t.remainingFreeScans == t.freeScanAllowance - 1)
    }

    @Test func runsOutAfterAllowance() {
        let t = tracker()
        for _ in 0..<t.freeScanAllowance { t.recordScan() }
        #expect(!t.hasFreeScans)
        #expect(t.remainingFreeScans == 0)
    }

    @Test func remainingNeverGoesNegative() {
        let t = tracker()
        for _ in 0..<(t.freeScanAllowance + 3) { t.recordScan() }
        #expect(t.remainingFreeScans == 0)
        #expect(!t.hasFreeScans)
    }

    @Test func countPersistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "test-persist-\(UUID().uuidString)")!
        let first = ScanLimitTracker(defaults: suite)
        first.recordScan()
        first.recordScan()
        let second = ScanLimitTracker(defaults: suite)
        #expect(second.scansUsed == 2)
    }
}

// MARK: - Parser

struct ReceiptParserTests {

    @Test func parsesSubtotalTaxTotal() {
        let text = """
        THE CORNER BISTRO
        Cheeseburger      18.00
        Fries              6.00
        SUBTOTAL          45.00
        TAX                3.71
        TOTAL             48.71
        """
        let r = ReceiptParser.parse(text)
        #expect(r.subtotal == 45.00)
        #expect(r.tax == 3.71)
        #expect(r.total == 48.71)
    }

    @Test func parsesPrintedTipSuggestions() {
        let text = """
        SUBTOTAL          45.00
        TAX                3.71
        TOTAL             48.71
        Tip Guide
        15%   7.31
        18%   8.77
        20%   9.74
        """
        let r = ReceiptParser.parse(text)
        #expect(r.suggestedTips.contains(SuggestedTip(percent: 15, amount: 7.31)))
        #expect(r.suggestedTips.contains(SuggestedTip(percent: 18, amount: 8.77)))
        #expect(r.suggestedTips.contains(SuggestedTip(percent: 20, amount: 9.74)))
    }

    @Test func doesNotMistakeSubtotalForTotal() {
        let text = """
        SUBTOTAL          45.00
        TAX                3.71
        TOTAL             48.71
        """
        let r = ReceiptParser.parse(text)
        #expect(r.total == 48.71)   // not 45.00
    }

    @Test func handlesDollarSignsAndCommas() {
        let text = """
        Subtotal   $1,250.00
        Sales Tax    $103.13
        Total      $1,353.13
        """
        let r = ReceiptParser.parse(text)
        #expect(r.subtotal == 1250.00)
        #expect(r.tax == 103.13)
        #expect(r.total == 1353.13)
    }

    @Test func parsesMerchantNameCleaningGarbage() {
        let text = """
        100%
        LTE
        Welcome to Kitchen Step!
        Order# 37234728
        Eat In Order
        """
        let r = ReceiptParser.parse(text)
        #expect(r.restaurantName == "Kitchen Step")
    }

    @Test func parsesMerchantNameNoWelcome() {
        let text = """
        12:00 PM
        Da Andrea
        Server: John
        """
        let r = ReceiptParser.parse(text)
        #expect(r.restaurantName == "Da Andrea")
    }
}

// MARK: - Parser, real-world OCR layouts (column format, parens tips)

struct ReceiptParserRealWorldTests {

    // Vision OCRs two-column receipts as a block of labels then a block of values.
    @Test func parsesColumnLayout() {
        let text = """
        Mama Mia Pizzeria
        Large Pepperoni Pizza
        Garlic Knots
        2 Sodas
        Subtotal
        Tax
        Total
        $18.00
        $6.50
        $4.00
        $28.50
        $2.42
        $30.92
        """
        let r = ReceiptParser.parse(text)
        #expect(r.subtotal == 28.50)
        #expect(r.tax == 2.42)
        #expect(r.total == 30.92)
    }

    @Test func parsesTipInParentheses() {
        let r = ReceiptParser.parse("15% ($3.00)\n18% ($3.60)\n20% ($4.00)")
        #expect(r.suggestedTips.contains(SuggestedTip(percent: 15, amount: 3.00)))
        #expect(r.suggestedTips.contains(SuggestedTip(percent: 20, amount: 4.00)))
    }

    @Test func parsesMultipleTipsOnOneLine() {
        let r = ReceiptParser.parse("Suggested Gratuity:\n15% ($4.28), 18% ($5.13), 20% ($5.70)")
        #expect(r.suggestedTips.count == 3)
        #expect(r.suggestedTips.contains(SuggestedTip(percent: 18, amount: 5.13)))
    }

    @Test func recognizesGrandTotalInColumnLayout() {
        let text = """
        Subtotal
        Tax
        Grand Total
        $20.00
        $1.78
        $21.78
        """
        let r = ReceiptParser.parse(text)
        #expect(r.total == 21.78)
        #expect(r.subtotal == 20.00)
    }

    // Grand-total line failed OCR: items sum to the subtotal, tax follows → compute total.
    @Test func recoversMissingTotalFromItemSum() {
        let text = """
        8oz Sirloin
        Grilled Salmon
        Subtotal
        Tax
        $42.00
        $38.00
        $80.00
        $6.40
        """
        let r = ReceiptParser.parse(text)
        #expect(r.subtotal == 80.00)
        #expect(r.tax == 6.40)
        #expect(r.total == 86.40)   // computed = subtotal + tax
    }
}

// MARK: - Parser, real Vision OCR captured from RECEIPTS SAMPLE 2
//
// Fixtures are the actual newline-joined output Vision produced for these photos (sideways
// receipts, two copies per frame, currency-symbol slips, split tip suggestions). They lock in the
// parsing behaviour the field photos exposed. See also OCRIntegrationTests for the end-to-end path.

struct ReceiptParserSampleReceiptTests {

    private func approx(_ a: Double, _ b: Double, _ tol: Double = 0.02) -> Bool { abs(a - b) <= tol }

    // Eataly: two-column, two copies, "Suggested Tip" with a trailing total-with-tip column.
    @Test func eatalyColumnTipsAndSummary() {
        let r = ReceiptParser.parse("""
        EATALY
        Subtotal
        Tax
        Amount Paid
        $42.00
        $3.73
        $45.73
        Suggested Tip:
        20%
        22%
        25%
        $8.40
        $9.24
        $10.50
        $54.13
        $54.97
        $56.23
        """)
        #expect(approx(r.subtotal, 42.00))
        #expect(approx(r.tax, 3.73))
        #expect(approx(r.total, 45.73))
        #expect(r.suggestedTips.contains { $0.percent == 20 && approx($0.amount, 8.40) })
        #expect(TipCalculator.overallBasis(for: r)?.basis == .preTax)
    }

    // Hutong: "22% = $" split from its amount, plus an "Amount/+Tip/=Total" payment block to skip.
    @Test func hutongSplitTipsSkipsPaymentBlock() {
        let r = ReceiptParser.parse("""
        Amount:
        + Tip:
        = Total:
        $455.10
        91.96
        547.66
        Complete Subtotal
        Subtotal
        Tax
        Total
        Balance Due
        Suggested Tip
        22% = $
        20% = $
        18% = $
        91.96
        83.60
        75.24
        418.00
        418.00
        37.10
        455.10
        455.10
        """)
        #expect(approx(r.subtotal, 418.00))
        #expect(approx(r.tax, 37.10))
        #expect(approx(r.total, 455.10))
        #expect(TipCalculator.overallBasis(for: r)?.basis == .preTax)
    }

    // MGM airport: genuine post-tax suggestions ("20% = $3.41" on the tax-inclusive total).
    @Test func mgmDetectsPostTaxSuggestions() {
        let r = ReceiptParser.parse("""
        15.75
        Subtotal
        Tax
        Total
        Due
        $15.75
        $1.32
        $17.07
        22% = $3.76
        20% = $3.41
        18% = $3.07
        """)
        #expect(approx(r.subtotal, 15.75))
        #expect(approx(r.total, 17.07))
        #expect(TipCalculator.overallBasis(for: r)?.basis == .postTax)
    }

    // Bacari: auto-gratuity already on the bill; "+N%" suggestions are additional, not the basis.
    @Test func bacariCapturesAutoGratuityAndDropsAdditionalTips() {
        let r = ReceiptParser.parse("""
        Subtotal
        Auto Gratuity (20.00%)
        Sales Tax
        4% Optional Service Fee*
        Amount
        $868.00
        $173.60
        $82.43
        $34.72
        $1,158.75
        + Additional Tip:
        = Total:
        Suggested Additional Tip:
        + 2%: (Tip $17.36 Total $1,176.11)
        + 3%: (Tip $26.04 Total $1,184.79)
        """)
        #expect(approx(r.subtotal, 868.00))
        #expect(approx(r.tax, 82.43))
        #expect(approx(r.total, 1158.75))           // not the "$1,176.11" additional-tip row
        #expect(r.includedGratuity?.percent == 20)
        #expect(approx(r.includedGratuity?.amount ?? 0, 173.60))
        #expect(r.suggestedTips.isEmpty)
    }

    // Malibu Farm: "20% = $ 40.00" gratuity suggestions split across lines + "Balance Due".
    @Test func malibuColumnGratuitySuggestions() {
        let r = ReceiptParser.parse("""
        Subtotal
        Tax
        Total
        Balance Due
        Suggested Gratuity
        20% =
        $ 40.00
        22% =
        $
        44.00
        25% =
        $
        50.00
        200.00
        17.75
        217.75
        217.75
        """)
        #expect(approx(r.subtotal, 200.00))
        #expect(approx(r.tax, 17.75))
        #expect(approx(r.total, 217.75))
        #expect(r.suggestedTips.count == 3)
    }

    // Tip amount printed with a decimal-comma OCR slip ("$34,50") still reads as 34.50.
    @Test func toleratesDecimalCommaInTipAmount() {
        let r = ReceiptParser.parse("Subtotal\nTax\nTotal\n$172.50\n$15.31\n$187.81\n20% is $34,50")
        #expect(r.suggestedTips.contains { $0.percent == 20 && approx($0.amount, 34.50) })
    }

    // Madre: gratuity printed *after* the pre-gratuity total — the grand total must include it.
    @Test func autoGratuityTotalIncludesGratuity() {
        let r = ReceiptParser.parse("""
        Subtotal          520.00
        Tax                61.88
        Total             581.88
        Gratuity 20.00%   104.00
        Total             685.88
        Balance Due       685.88
        A 20% Suggested service charge
        to parties of six or larger
        """)
        #expect(r.subtotal == 520.00)
        #expect(r.tax == 61.88)
        #expect(r.total == 685.88)                       // not the pre-gratuity 581.88
        #expect(r.includedGratuity?.percent == 20)
        #expect(r.includedGratuity?.amount == 104.00)
    }

    // Madre read as two columns (labels and values in separate blocks, with item lines and a second
    // copy): the gratuity is confirmed via subtotal×% / post-gratuity total, not a same-line amount.
    @Test func autoGratuityDetectedInTwoColumnLayout() {
        let r = ReceiptParser.parse("""
        MADRE!
        SubTotal
        USD $ 685.88
        Customer Copy
        MADRE!
        3 Salsas & Guac w/ chips (2 @17.00)
        34.00
        Tres Leches (4 @9.00)
        36.00
        Subtotal
        Tax
        Total
        Gratuity 20.00%
        Total
        Balance Due
        520.00
        61.88
        581.88
        104.00
        685.88
        685.88
        A 20% Suggested service charge
        to parties of six or larger
        """)
        #expect(r.subtotal == 520.00)
        #expect(r.total == 685.88)                       // includes the gratuity, not 581.88
        #expect(r.includedGratuity?.percent == 20)
        #expect(r.includedGratuity?.amount == 104.00)
    }

    // Sangria (euro, VAT-inclusive): a "Tip 10%" line plus "TIPS 10 INCLUDED" is an included
    // gratuity; the VAT-rate lines ("Base 33,98 TAX 23%") must not be read as the tax total.
    @Test func includedTipEuroReceipt() {
        let r = ReceiptParser.parse("""
        SubTotal          121,35
        Tip 10%            12,14
        TOTAL             133,49 EUR
        Base 33,98 TAX 23%  7,82
        Base 80,78 TAX 13.5% 10,91
        ===== TIPS 10 INCLUDED =====
        """)
        #expect(r.currencySymbol == "€")
        #expect(r.subtotal == 121.35)
        #expect(r.total == 133.49)
        #expect(r.includedGratuity?.percent == 10)
        #expect(r.includedGratuity?.amount == 12.14)
        #expect(abs(r.tax) < 0.02)                        // VAT is embedded, not an added tax
    }

    // Auto-gratuity summary Vision interleaves a value between label groups (IMG_4046): the labels
    // and values still zip by order — Subtotal 569.40, Gratuity 109.50, Tax 52.01, Amount 730.91.
    @Test func autoGratuityInterleavedLabelsAndValues() {
        let r = ReceiptParser.parse("""
        Subtotal
        Auto Gratuity (20.00%)
        $569.40
        Sales Tax
        Amount
        $109.50
        $52.01
        $730.91
        + Additional Tip:
        Total,
        730.91
        """)
        #expect(r.subtotal == 569.40)
        #expect(r.tax == 52.01)
        #expect(r.total == 730.91)
        #expect(r.includedGratuity?.percent == 20)
        #expect(r.includedGratuity?.amount == 109.50)
    }

    // A boilerplate "20% service charge to parties of six+" note (no charged amount) is not a gratuity.
    @Test func serviceChargeNoteWithoutAmountIsNotGratuity() {
        let r = ReceiptParser.parse("""
        Subtotal   50.00
        Tax         4.00
        Total      54.00
        A 20% service charge applies to parties of six or larger
        """)
        #expect(r.includedGratuity == nil)
        #expect(r.total == 54.00)
    }

    // Euro currency is detected, but with no labelled total or clean triple we do NOT fabricate one
    // from the largest amount — the screen shows blanks and asks the user to enter them.
    @Test func detectsEuroCurrencyButDoesNotGuessTotal() {
        let r = ReceiptParser.parse("The Beekeeper\n€14.00\n€26.00\n€180.00\nService charge\nnot included")
        #expect(r.currencySymbol == "€")
        #expect(r.total == 0)
        #expect(r.subtotal == 0)
    }

    // A foreign-card "Total Transaction Amount … USD" duplicate must not override the EUR total.
    @Test func ignoresCardTransactionAmountForTotal() {
        let r = ReceiptParser.parse("""
        TOTAL TRANSACTION AMOUNT 164,21 USD
        SubTotal   121,35
        TOTAL      133,49 EUR
        """)
        #expect(r.currencySymbol == "€")
        #expect(r.total == 133.49)
        #expect(r.subtotal == 121.35)
    }

    // Subtotal missing but total + tax present → derive subtotal and flag it.
    @Test func infersSubtotalWhenNotPrinted() {
        let r = ReceiptParser.parse("Tax              2.00\nTotal           27.00")
        #expect(approx(r.subtotal, 25.00))
        #expect(r.subtotalInferred)
    }

    // Kitchen Step receipt: two-column interleaved summary, with employee benefits charge skipped,
    // and suggested tips printed below the header where percentages appear above it in OCR layout.
    @Test func kitchenStepReceiptParsing() {
        let text = """
        Welcome to Kitchen Step!
        Order# 37234728
        Eat In Order
        Server: Fanny G
        Table: B10
        Date: 3/11/26, 6:19 PM
        MAC & CHZ w/ BAC & ROOMS
        BATTELO CAB 9oz
        $19.93
        $26.45
        Total Item Count:
        2
        Subtotal:
        3% Emp Benefits and Retention:
        Total Tax:
        $46.38
        $1.39
        $3.16
        $50.93
        Total:
        Total Paid:
        Order Balance due:
        $0.00
        $50.93
        %
        18.00% of sale:
        20.00% of sale:
        22.00% of sale:
        Suggested Gratuity
        Tip
        $8.35 =
        $9.28 =
        $10.20 =
        Total
        $59.28
        $60.21
        $61.13
        Pleasure Dining with us!
        Please contact
        snadeem@mca-airports.com
        for feedback!
        """
        let r = ReceiptParser.parse(text)
        #expect(approx(r.subtotal, 46.38))
        #expect(approx(r.tax, 3.16))
        #expect(approx(r.total, 50.93))
        #expect(r.suggestedTips.count == 3)
        #expect(r.suggestedTips.contains { $0.percent == 18 && approx($0.amount, 8.35) })
        #expect(r.suggestedTips.contains { $0.percent == 20 && approx($0.amount, 9.28) })
        #expect(r.suggestedTips.contains { $0.percent == 22 && approx($0.amount, 10.20) })
    }

    // Da Andrea receipt: contains suggested tips using the word "Gratuity" below the grand total.
    // Ensure these suggested tips are not misidentified as an already-included auto-gratuity.
    @Test func daAndreaSuggestedGratuityNotAutoGratuity() {
        let text = """
        Da Andrea
        160 8th Ave
        New York, NY 10011
        (212) 354-5971
        Server: Grace
        Table: 20 Guests: 5
        1 First Course Flatbread 29.95
        1 First Course Barbabietole 29.95
        1 BURRATAA 18.00
        Bar Sub Total: 0.00
        Food Sub Total: 182.80
        Tax 1: 16.23
        ========
        TOTAL: $199.03
        4/25/2024 11:53 AM
        Suggested Gratuity
        18% Gratuity = $32.90
        20% Gratuity = $36.56
        22% Gratuity = $40.22
        """
        let r = ReceiptParser.parse(text)
        #expect(approx(r.subtotal, 182.80))
        #expect(approx(r.tax, 16.23))
        #expect(approx(r.total, 199.03))
        #expect(r.includedGratuity == nil)
        #expect(r.suggestedTips.count == 3)
        #expect(r.suggestedTips.contains { $0.percent == 18 && approx($0.amount, 32.90) })
        #expect(r.suggestedTips.contains { $0.percent == 20 && approx($0.amount, 36.56) })
        #expect(r.suggestedTips.contains { $0.percent == 22 && approx($0.amount, 40.22) })
    }
}

// MARK: - OCR integration (real Vision over bundled sample photos)
//
// Exercises the full image → text → ReceiptData path, including the OCRService orientation pass,
// against the sideways field photos. Sample images live in TIP CALCULATORTests/Fixtures.

import UIKit

private final class FixtureLocator {}

struct OCRIntegrationTests {

    private func parse(_ name: String) async -> ReceiptData? {
        let bundle = Bundle(for: FixtureLocator.self)
        guard let url = bundle.url(forResource: name, withExtension: "jpeg"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        let text = await OCRService.recognizeText(in: image)
        return ReceiptParser.parse(text)
    }

    private func approx(_ a: Double, _ b: Double, _ tol: Double = 0.05) -> Bool { abs(a - b) <= tol }

    @Test func mgmReadsPostTaxFromSidewaysPhoto() async throws {
        let r = try #require(await parse("IMG_6102"))
        #expect(approx(r.subtotal, 15.75))
        #expect(approx(r.total, 17.07))
        #expect(TipCalculator.overallBasis(for: r)?.basis == .postTax)
    }

    @Test func eatalyReadsPreTaxFromPhoto() async throws {
        let r = try #require(await parse("IMG_1174"))
        #expect(approx(r.subtotal, 42.00))
        #expect(approx(r.total, 45.73))
        #expect(TipCalculator.overallBasis(for: r)?.basis == .preTax)
    }

    @Test func bacariReadsAutoGratuityFromPhoto() async throws {
        let r = try #require(await parse("IMG_3316"))
        #expect(r.includedGratuity != nil)
        #expect(approx(r.total, 1158.75, 0.5))
    }

    // Second Bacari copy whose auto-gratuity summary Vision interleaves (a value between labels).
    @Test func bacariInterleavedAutoGratuityFromPhoto() async throws {
        let r = try #require(await parse("IMG_4046"))
        #expect(approx(r.subtotal, 569.40))
        #expect(approx(r.tax, 52.01))
        #expect(approx(r.total, 730.91))
        #expect(r.includedGratuity?.percent == 20)
        #expect(approx(r.includedGratuity?.amount ?? 0, 109.50))
    }

    @Test func fourDogsReadsCleanSummaryFromTwoCopyPhoto() async throws {
        let r = try #require(await parse("IMG_0734"))
        #expect(approx(r.subtotal, 195.00))
        #expect(approx(r.tax, 10.95))
        #expect(approx(r.total, 205.95))
    }
}
