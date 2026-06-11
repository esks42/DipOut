//
//  ReviewView.swift
//  TIP CALCULATOR
//
//  Confirm / correct the OCR'd amounts and see each printed tip's basis.
//

import SwiftUI

struct ReviewView: View {
    @Bindable var session: ReceiptSession
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle("Review")

                    // Surface the receipt's tip status up front: an already-included gratuity (strong
                    // warning) takes priority; otherwise flag when no suggestions were printed.
                    if session.hasIncludedGratuity {
                        GratuityBanner(percent: session.receipt.includedGratuity?.percent,
                                       amount: session.receipt.includedGratuity?.amount ?? 0,
                                       basis: session.gratuityBasis?.basis,
                                       symbol: sym)
                    } else if session.receipt.suggestedTips.isEmpty {
                        InfoBanner(title: "No tip suggestions detected",
                                   detail: "This receipt didn't print a tip. Pick a percentage on the next screen to tip on the subtotal.")
                    }

                    VStack(spacing: 0) {
                        amountRow("Subtotal", $session.receipt.subtotal, sym)
                        Divider().overlay(Theme.ink.opacity(0.08))
                        amountRow("Tax", $session.receipt.tax, sym)
                        if session.hasIncludedGratuity {
                            Divider().overlay(Theme.ink.opacity(0.08))
                            amountRow(gratuityLabel, gratuityAmount, sym)
                        }
                        Divider().overlay(Theme.ink.opacity(0.08))
                        amountRow("Total", $session.receipt.total, sym)
                    }
                    .padding(.horizontal, 18)
                    .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))

                    Text(couldNotRead
                         ? "Couldn't read this receipt. Tap each value to enter it."
                         : "Tap any value to correct what the scan read.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(couldNotRead ? Theme.warn : Theme.inkSecondary)
                        .padding(.horizontal, 4)

                    if !session.receipt.suggestedTips.isEmpty {
                        SectionHeader("Tips printed on the receipt").padding(.top, 6)

                        let sortedTips = session.receipt.suggestedTips.sorted {
                            if abs($0.amount - $1.amount) < 0.01 {
                                return ($0.percent ?? 0) < ($1.percent ?? 0)
                            }
                            return $0.amount < $1.amount
                        }
                        ForEach(Array(sortedTips.enumerated()), id: \.offset) { _, tip in
                            let result = TipCalculator.detectBasis(
                                for: tip, subtotal: session.receipt.subtotal, tax: session.receipt.tax)
                            HStack(spacing: 12) {
                                Text(tip.percent.map { String(format: "%.0f%%", $0) } ?? "—")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Theme.ink)
                                    .frame(width: 56, alignment: .leading)
                                Text(money(tip.amount, sym))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                BasisBadge(basis: result.basis)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }

                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            CardButton(title: confirmTitle, systemImage: confirmIcon,
                       background: Theme.yellow, foreground: .black, minHeight: 60,
                       action: onConfirm)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .opacity(session.receipt.subtotal <= 0 ? 0.4 : 1)
                .disabled(session.receipt.subtotal <= 0)
        }
    }

    private var sym: String { session.receipt.currencySymbol }

    /// Nothing usable was parsed — prompt manual entry rather than implying a (wrong) reading.
    private var couldNotRead: Bool { session.receipt.subtotal <= 0 && session.receipt.total <= 0 }

    // Tailor the call-to-action: the tip's already on the bill (just split it), the suggestion was
    // charged on tax (recompute a fair one), or it's up to you (pick a tip and split).
    private var confirmTitle: String {
        if session.hasIncludedGratuity { return "Split the Bill" }
        if session.verdict?.basis == .postTax { return "Calculate Fair Tip" }
        return "Choose Tip & Split"
    }

    private var confirmIcon: String {
        if session.hasIncludedGratuity { return "person.2.fill" }
        if session.verdict?.basis == .postTax { return "equal.circle.fill" }
        return "slider.horizontal.3"
    }

    private var gratuityLabel: String {
        session.receipt.includedGratuity?.percent.map { "Gratuity (\(Int($0))%)" } ?? "Gratuity"
    }

    /// Editable binding into the already-included gratuity amount.
    private var gratuityAmount: Binding<Double> {
        Binding(
            get: { session.receipt.includedGratuity?.amount ?? 0 },
            set: { session.receipt.includedGratuity = SuggestedTip(
                percent: session.receipt.includedGratuity?.percent, amount: $0) }
        )
    }

    private func textRow(_ label: String, _ value: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            TextField("Unknown", text: value)
                .font(.system(size: 18, weight: .bold))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 16)
    }

    private func amountRow(_ label: String, _ value: Binding<Double>, _ symbol: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            // Fixed value column: symbol pinned left, amount right-aligned — so the symbols line up
            // down the column regardless of how wide each number is.
            HStack(spacing: 0) {
                Text(symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.inkSecondary)
                Spacer(minLength: 6)
                TextField(label, value: value, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 140)
        }
        .padding(.vertical, 16)
    }
}

struct BasisBadge: View {
    let basis: TipBasis

    var body: some View {
        switch basis {
        case .preTax:  badge("pre-tax", Theme.good, "checkmark.seal.fill")
        case .postTax: badge("on tax", Theme.warn, "exclamationmark.triangle.fill")
        case .unknown: badge("unclear", Theme.inkSecondary, "questionmark.circle")
        }
    }

    private func badge(_ text: String, _ color: Color, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
    }
}
