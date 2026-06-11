//
//  TipCalculator.swift
//  TIP CALCULATOR
//
//  Pure calculation engine: tip-basis detection, pre-tax recalculation, and even split.
//  No framework dependencies beyond Foundation — fully unit-testable.
//

import Foundation

/// Result of analysing one printed tip suggestion.
nonisolated struct TipBasisResult: Equatable {
    let basis: TipBasis
    /// The percentage in play (printed if known, otherwise inferred).
    let percent: Double
    /// Dollars overpaid versus a pre-tax tip at the same percentage (0 unless `.postTax`).
    let overcharge: Double
}

/// Rounding applied to a freshly-calculated tip.
nonisolated enum TipRounding: Equatable {
    case exact
    case roundUpToDollar
}

/// An even bill split with exact-cent reconciliation.
nonisolated struct BillSplit: Equatable {
    let people: Int
    let perPersonTip: Double
    let perPersonTotal: Double
    /// Per-person total shares in dollars; reconciled so they sum to the bill total to the cent.
    let totalShares: [Double]
}

nonisolated enum TipCalculator {

    /// Common US tip rates used when a suggestion prints an amount but no percentage.
    static let commonRates: [Double] = [10, 15, 18, 20, 22, 25]
    /// Dollar tolerance when matching a printed amount to a candidate.
    static let amountTolerance = 0.02
    /// Percentage-point tolerance when inferring a rate from an amount.
    static let percentTolerance = 0.4

    // MARK: Tip-basis detection

    static func detectBasis(for tip: SuggestedTip, subtotal: Double, tax: Double) -> TipBasisResult {
        guard subtotal > 0 else { return TipBasisResult(basis: .unknown, percent: 0, overcharge: 0) }
        let postBase = subtotal + tax

        if let p = tip.percent {
            let candidatePre = subtotal * p / 100
            let candidatePost = postBase * p / 100
            let matchesPre = abs(tip.amount - candidatePre) <= amountTolerance
            let matchesPost = abs(tip.amount - candidatePost) <= amountTolerance
            if matchesPost && !matchesPre {
                return TipBasisResult(basis: .postTax, percent: p, overcharge: tax * p / 100)
            } else if matchesPre {
                return TipBasisResult(basis: .preTax, percent: p, overcharge: 0)
            } else {
                return TipBasisResult(basis: .unknown, percent: p, overcharge: 0)
            }
        }

        // No percent printed — infer it from the amount against each base.
        let pPre = tip.amount / subtotal * 100
        let pPost = tip.amount / postBase * 100
        let nearPre = nearestCommonRate(pPre)
        let nearPost = nearestCommonRate(pPost)

        switch (nearPre, nearPost) {
        case let (.some(rPre), .some(rPost)):
            // Both plausible — pick whichever sits closer to a round rate.
            if abs(pPost - rPost) <= abs(pPre - rPre) {
                return TipBasisResult(basis: .postTax, percent: rPost, overcharge: tax * rPost / 100)
            } else {
                return TipBasisResult(basis: .preTax, percent: rPre, overcharge: 0)
            }
        case let (.some(rPre), nil):
            return TipBasisResult(basis: .preTax, percent: rPre, overcharge: 0)
        case let (nil, .some(rPost)):
            return TipBasisResult(basis: .postTax, percent: rPost, overcharge: tax * rPost / 100)
        case (nil, nil):
            return TipBasisResult(basis: .unknown, percent: 0, overcharge: 0)
        }
    }

    private static func nearestCommonRate(_ percent: Double) -> Double? {
        commonRates
            .map { ($0, abs($0 - percent)) }
            .filter { $0.1 <= percentTolerance }
            .min { $0.1 < $1.1 }?
            .0
    }

    /// Headline finding across all of a receipt's printed suggestions.
    /// Returns the post-tax suggestion with the biggest overcharge if any tip is computed on tax,
    /// otherwise a pre-tax result; `nil` when the receipt prints no suggestions.
    static func overallBasis(for receipt: ReceiptData) -> TipBasisResult? {
        let results = receipt.suggestedTips.map {
            detectBasis(for: $0, subtotal: receipt.subtotal, tax: receipt.tax)
        }
        guard !results.isEmpty else { return nil }
        if let worstPostTax = results.filter({ $0.basis == .postTax }).max(by: { $0.overcharge < $1.overcharge }) {
            return worstPostTax
        }
        return results.first { $0.basis == .preTax } ?? results.first
    }

    // MARK: Recalculation (always on the pre-tax subtotal)

    /// Tip on the pre-tax subtotal. With `.roundUpToDollar` the *new total* (subtotal + tax + tip)
    /// is rounded up to the next whole dollar and the tip absorbs the difference.
    static func recalculatedTip(subtotal: Double, tax: Double, percent: Double, rounding: TipRounding = .exact) -> Double {
        let exactTip = roundCents(subtotal * percent / 100)
        switch rounding {
        case .exact:
            return exactTip
        case .roundUpToDollar:
            let roundedTotal = (subtotal + tax + exactTip).rounded(.up)
            return roundCents(roundedTotal - subtotal - tax)
        }
    }

    static func newTotal(subtotal: Double, tax: Double, tip: Double) -> Double {
        roundCents(subtotal + tax + tip)
    }

    // MARK: Amount saved

    /// Money saved by tipping `actualTip` (computed on the pre-tax subtotal at `percent`) instead of
    /// the receipt's suggestion. If the receipt prints a suggestion at `percent`, that printed amount
    /// is the comparison; otherwise the comparison is `percent` applied to the tax-inclusive subtotal.
    /// Never negative.
    static func amountSaved(receipt: ReceiptData, percent: Double, actualTip: Double) -> Double {
        max(0, roundCents(comparisonTip(receipt: receipt, percent: percent) - actualTip))
    }

    /// The tip you'd otherwise have paid at `percent`. A saving only exists when the receipt
    /// actually computes its tip on the post-tax total; for fair (pre-tax) receipts or those with
    /// no suggestions there's nothing to compare against, so the comparison is the pre-tax tip
    /// itself (zero saving). On a post-tax receipt it's the printed suggestion at that rate if
    /// present, else `percent` applied to the tax-inclusive subtotal.
    static func comparisonTip(receipt: ReceiptData, percent: Double) -> Double {
        guard overallBasis(for: receipt)?.basis == .postTax else {
            return recalculatedTip(subtotal: receipt.subtotal, tax: receipt.tax, percent: percent)
        }
        if let printed = receipt.suggestedTips.first(where: { tip in
            tip.percent.map { abs($0 - percent) < 0.01 } ?? false
        }) {
            return printed.amount
        }
        return roundCents((receipt.subtotal + receipt.tax) * percent / 100)
    }

    // MARK: Even split

    static func split(tip: Double, total: Double, people: Int) -> BillSplit {
        precondition(people > 0, "people must be positive")
        let totalCents = Int((total * 100).rounded())
        let base = totalCents / people
        let remainder = totalCents % people
        let shares = (0..<people).map { i in
            Double(base + (i < remainder ? 1 : 0)) / 100
        }
        return BillSplit(
            people: people,
            perPersonTip: roundCents(tip / Double(people)),
            perPersonTotal: roundCents(total / Double(people)),
            totalShares: shares
        )
    }

    private static func roundCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
