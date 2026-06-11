//
//  ReceiptModels.swift
//  TIP CALCULATOR
//
//  Pure data models for the receipt-processing pipeline.
//  No UIKit / Vision dependencies — unit-testable in isolation.
//

import Foundation

/// A tip amount as *printed on the receipt*, optionally with its stated percentage.
nonisolated struct SuggestedTip: Equatable {
    /// Stated percent as printed (e.g. 18 for "18%"). `nil` when the receipt prints only an amount.
    let percent: Double?
    /// The dollar amount printed next to the suggestion.
    let amount: Double
}

/// The numbers extracted from a single receipt. Mutable so the Review screen can correct OCR slips.
nonisolated struct ReceiptData: Equatable {
    var restaurantName: String
    var subtotal: Double          // pre-tax
    var tax: Double
    var total: Double             // printed grand total
    var suggestedTips: [SuggestedTip]
    /// A gratuity/service charge already added to the bill (e.g. "Auto Gratuity (20%)"), if any.
    /// When present, the printed total already includes this and any "tips" printed are *additional*.
    var includedGratuity: SuggestedTip?
    /// Currency symbol detected on the receipt, for display only (math is percentage-based).
    var currencySymbol: String
    /// True when the subtotal wasn't printed and we derived it (total − tax, or item sum).
    var subtotalInferred: Bool

    init(restaurantName: String = "", subtotal: Double, tax: Double, total: Double, suggestedTips: [SuggestedTip] = [],
         includedGratuity: SuggestedTip? = nil, currencySymbol: String = "$",
         subtotalInferred: Bool = false) {
        self.restaurantName = restaurantName
        self.subtotal = subtotal
        self.tax = tax
        self.total = total
        self.suggestedTips = suggestedTips
        self.includedGratuity = includedGratuity
        self.currencySymbol = currencySymbol
        self.subtotalInferred = subtotalInferred
    }
}

/// Which figure a printed tip suggestion was computed against.
nonisolated enum TipBasis: Equatable {
    case preTax     // tip = subtotal × p%   (fair)
    case postTax    // tip = (subtotal+tax) × p%  (you're tipping on tax)
    case unknown    // couldn't determine
}
