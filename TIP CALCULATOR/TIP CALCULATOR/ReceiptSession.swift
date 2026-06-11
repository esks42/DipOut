//
//  ReceiptSession.swift
//  TIP CALCULATOR
//
//  Observable state for one receipt as it moves Scan → Review → Results.
//

import SwiftUI

@Observable
final class ReceiptSession {
    var receipt = ReceiptData(subtotal: 0, tax: 0, total: 0)
    var people = 2
    var targetPercent = 20.0
    var rounding: TipRounding = .exact
    var isProcessing = false
    /// On a receipt that already includes a gratuity, whether the user chose to add more on top.
    var addAdditionalTip = false
    /// Stores the raw OCR text for debugging purposes.
    var rawOCRText = ""

    /// Stable id for this receipt's history record; regenerated each scan so a new receipt
    /// becomes a new entry rather than overwriting the last.
    private(set) var recordID = UUID()

    /// Run OCR + parsing on a captured image, then seed the target % from what the receipt suggested.
    func load(image: UIImage) async {
        recordID = UUID()
        isProcessing = true
        addAdditionalTip = false
        let text = await OCRService.recognizeText(in: image)
        self.rawOCRText = text
        
        // Debug dump for OCR inspection
        do {
            try text.write(toFile: "/tmp/ocr_text.txt", atomically: true, encoding: .utf8)
            print("Successfully dumped OCR text to /tmp/ocr_text.txt")
        } catch {
            print("Failed to dump OCR text: \(error)")
        }
        
        receipt = ReceiptParser.parse(text)
        if let verdict = TipCalculator.overallBasis(for: receipt), verdict.percent > 0 {
            targetPercent = verdict.percent
        }
        isProcessing = false
    }

    // MARK: Derived values (the four user goals)

    var verdict: TipBasisResult? {
        return TipCalculator.overallBasis(for: receipt)
    }

    /// The verdict and overcharge corresponding to the currently selected targetPercent.
    var selectedVerdict: TipBasisResult? {
        guard let overall = verdict else { return nil }
        if overall.basis == .postTax {
            if let printed = receipt.suggestedTips.first(where: { tip in
                tip.percent.map { abs($0 - targetPercent) < 0.01 } ?? false
            }) {
                return TipCalculator.detectBasis(for: printed, subtotal: receipt.subtotal, tax: receipt.tax)
            }
            return TipBasisResult(basis: .postTax, percent: targetPercent, overcharge: (receipt.tax * targetPercent / 100))
        } else {
            return TipBasisResult(basis: overall.basis, percent: targetPercent, overcharge: 0)
        }
    }

    /// A gratuity already added to the bill means the printed total is final unless the user opts
    /// to tip more; in that case our calculated tip is *additional*, layered on the printed total.
    var hasIncludedGratuity: Bool { receipt.includedGratuity != nil }

    /// Whether the already-included gratuity was itself computed pre- or post-tax.
    var gratuityBasis: TipBasisResult? {
        receipt.includedGratuity.map {
            TipCalculator.detectBasis(for: $0, subtotal: receipt.subtotal, tax: receipt.tax)
        }
    }

    var recalculatedTip: Double {
        TipCalculator.recalculatedTip(subtotal: receipt.subtotal, tax: receipt.tax, percent: targetPercent, rounding: rounding)
    }

    /// The tip actually applied to the bill: our pre-tax tip normally; on a gratuity-included
    /// receipt it's the additional tip (zero unless the user opts in).
    var appliedTip: Double {
        guard hasIncludedGratuity else { return recalculatedTip }
        return addAdditionalTip ? recalculatedTip : 0
    }

    var newTotal: Double {
        guard hasIncludedGratuity else {
            return TipCalculator.newTotal(subtotal: receipt.subtotal, tax: receipt.tax, tip: appliedTip)
        }
        // Printed total already includes tax + gratuity; only an additional tip is layered on.
        return TipCalculator.newTotal(subtotal: receipt.total, tax: 0, tip: appliedTip)
    }

    var split: BillSplit {
        TipCalculator.split(tip: appliedTip, total: newTotal, people: max(people, 1))
    }

    /// The tip you'd otherwise have paid at the chosen rate (printed suggestion or % on tax-inclusive total).
    var comparisonTip: Double {
        TipCalculator.comparisonTip(receipt: receipt, percent: targetPercent)
    }

    /// Whole-bill amount saved by tipping pre-tax.
    var saved: Double {
        TipCalculator.amountSaved(receipt: receipt, percent: targetPercent, actualTip: recalculatedTip)
    }

    /// Each person's share of the saving.
    var savedShare: Double { saved / Double(max(people, 1)) }
}

/// Two decimals with a thousands separator, no symbol: "1,158.75".
func amountString(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(2)).grouping(.automatic))
}

/// Formats an amount with the receipt's currency symbol, e.g. "$1,158.75" or "€12.34".
func money(_ value: Double, _ symbol: String = "$") -> String {
    "\(symbol)\(amountString(value))"
}
