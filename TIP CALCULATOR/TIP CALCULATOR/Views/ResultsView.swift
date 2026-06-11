//
//  ResultsView.swift
//  TIP CALCULATOR
//
//  The four answers: tip-basis verdict, recalculated pre-tax tip + new total, and the split.
//

import SwiftUI

struct ResultsView: View {
    @Bindable var session: ReceiptSession
    var onHome: () -> Void = {}
    @Environment(HistoryStore.self) private var history
    @Environment(\.scenePhase) private var scenePhase

    /// Commit a record once the chosen tip has been left untouched this long.
    private let idleCommit: Duration = .seconds(20 * 60)

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle("Your Tip")

                    // The "tip included" / "no suggestions" status lives on the Review screen now;
                    // here we keep only the pre/post-tax verdict and the add-a-tip control.
                    if session.hasIncludedGratuity {
                        Toggle("Add an additional tip", isOn: $session.addAdditionalTip)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .tint(Theme.yellow)
                            .padding(18)
                            .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                    } else if session.selectedVerdict != nil {
                        VerdictBanner(verdict: session.selectedVerdict, symbol: sym)
                    }

                    if showTipControls {
                        // Pick the percentage first, then the amount + new total update right below it.
                        VStack(spacing: 14) {
                            PercentSelector(selection: $session.targetPercent)
                            Toggle("Round up to whole dollar", isOn: roundUp)
                                .font(.system(size: 16, weight: .medium))
                                .tint(Theme.yellow)
                        }
                        .padding(18)
                        .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))

                        // Hero: your fair tip (green) vs. what you'd have paid, and the difference.
                        TipComparisonCard(label: session.hasIncludedGratuity ? "Additional tip" : "Your tip",
                                          tip: session.recalculatedTip,
                                          percent: session.targetPercent,
                                          wouldHavePaid: session.comparisonTip,
                                          symbol: sym)
                    }

                    StatCard(prefix: sym, value: amt(session.newTotal), label: "New total",
                             background: Theme.yellow.opacity(0.45), minHeight: 128)

                    // Split
                    SectionHeader("Split").padding(.top, 6)

                    HStack {
                        Text("\(session.people) \(session.people == 1 ? "person" : "people")")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Stepper("", value: $session.people, in: 1...30).labelsHidden()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    if showTipControls {
                        TipComparisonCard(label: session.hasIncludedGratuity ? "Additional tip each" : "Tip each",
                                          tip: session.split.perPersonTip,
                                          percent: session.targetPercent,
                                          wouldHavePaid: session.comparisonTip / Double(max(session.people, 1)),
                                          symbol: sym)
                    }

                    StatCard(prefix: sym, value: amt(session.split.perPersonTotal), label: "Total each",
                             background: Theme.yellow.opacity(0.45), minHeight: 110)

                    if hasUnevenShares {
                        Text("To the cent: " + session.split.totalShares.map { money($0, sym) }.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.horizontal, 4)
                    }

                    CardButton(title: "Home", systemImage: "house.fill",
                               background: Theme.yellow, foreground: .black) {
                        commit()
                        onHome()
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Idle commit: restarts whenever the chosen tip changes; fires after 20 min of no change.
        .task(id: commitKey) {
            try? await Task.sleep(for: idleCommit)
            if !Task.isCancelled { commit() }
        }
        // Commit when the app is backgrounded/closed…
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { commit() }
        }
        // …or when leaving the results screen (back / switch to History).
        .onDisappear { commit() }
    }

    private var commitKey: String {
        "\(session.recordID)|\(session.targetPercent)|\(session.rounding == .roundUpToDollar)|\(session.people)"
    }

    /// Save (or update) this receipt's per-person history entry.
    private func commit() {
        let people = max(session.people, 1)
        history.upsert(TipRecord(id: session.recordID,
                                 date: .now,
                                 restaurantName: session.receipt.restaurantName,
                                 people: people,
                                 billShare: (session.receipt.subtotal + session.receipt.tax) / Double(people),
                                 tipShare: session.split.perPersonTip,
                                 savedShare: session.savedShare))
    }

    private var sym: String { session.receipt.currencySymbol }

    /// Tip controls are hidden on a gratuity-included receipt until the user opts to add more.
    private var showTipControls: Bool { !session.hasIncludedGratuity || session.addAdditionalTip }

    private func amt(_ v: Double) -> String { amountString(v) }

    private var roundUp: Binding<Bool> {
        Binding(get: { session.rounding == .roundUpToDollar },
                set: { session.rounding = $0 ? .roundUpToDollar : .exact })
    }

    private var hasUnevenShares: Bool { Set(session.split.totalShares).count > 1 }
}

/// Hero card for the results screen: your fair (pre-tax) tip in brand green, the tip you'd
/// otherwise have paid (tax-inclusive, struck through), and the difference you save.
struct TipComparisonCard: View {
    var label: String = "Your tip"
    let tip: Double
    let percent: Double
    let wouldHavePaid: Double
    var symbol: String = "$"

    /// Only show the comparison when the receipt's tip was actually charged on tax — otherwise
    /// there's no genuine saving and a struck-through "you'd have paid" would be misleading.
    private var hasSaving: Bool { wouldHavePaid - tip > 0.005 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(symbol)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Theme.positive.opacity(0.85))
                    .fixedSize()
                Text(amountString(tip))
                    .font(.system(size: 62, weight: .black))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .layoutPriority(1)
                    .foregroundStyle(Theme.positive)
                Text("\(label) · \(Int(percent))%")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.leading, 3)
                Spacer(minLength: 0)
            }

            if hasSaving {
                compareRow("You'd have paid", note: "incl. tax", wouldHavePaid,
                           color: Theme.inkSecondary, strike: true)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.positiveBg.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private func compareRow(_ label: String, note: String?, _ value: Double,
                            color: Color, bold: Bool = false, strike: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.ink)
            if let note {
                Text(note).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Text(money(value, symbol))
                .font(.system(size: 18, weight: bold ? .bold : .semibold))
                .monospacedDigit()
                .strikethrough(strike, color: Theme.inkSecondary)
                .foregroundStyle(color)
        }
    }
}

/// On-theme percentage picker: preset pills (10/15/20/25) plus a custom % entry.
struct PercentSelector: View {
    @Binding var selection: Double
    var presets: [Double] = [10, 15, 18, 20, 25]

    @State private var customActive = false
    @FocusState private var customFocused: Bool

    private func isPreset(_ v: Double) -> Bool { presets.contains { abs($0 - v) < 0.01 } }
    private var showCustom: Bool { customActive || !isPreset(selection) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { rate in
                    pill("\(Int(rate))%", on: !showCustom && abs(selection - rate) < 0.01) {
                        customActive = false
                        customFocused = false
                        selection = rate
                    }
                }
                pill("Custom", on: showCustom) {
                    customActive = true
                    customFocused = true
                }
            }

            if showCustom {
                HStack(spacing: 8) {
                    Text("Custom tip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    TextField("0", value: $selection, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .focused($customFocused)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 64)
                    Text("%").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.inkSecondary)
                    Stepper("", value: $selection, in: 0...100, step: 1).labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func pill(_ text: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(on ? .black : Theme.ink.opacity(0.55))
                .background(on ? Theme.yellow : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct VerdictBanner: View {
    let verdict: TipBasisResult?
    var symbol: String = "$"

    var body: some View {
        switch verdict {
        case let v? where v.basis == .postTax:
            banner(Theme.warn, "exclamationmark.triangle.fill",
                   "Tip suggested on the post-tax total",
                   "At \(Int(v.percent))%, \(money(v.overcharge, symbol)) of the tip is charged on tax.")
        case let v? where v.basis == .preTax:
            banner(Theme.good, "checkmark.seal.fill",
                   "Suggested tips look fair",
                   "They're calculated on the pre-tax subtotal.")
        default:
            banner(Theme.inkSecondary, "info.circle.fill",
                   "No tip suggestions detected",
                   "Pick a percentage below to tip on the subtotal.")
        }
    }

    private func banner(_ color: Color, _ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                Text(detail).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Shown when the bill already carries a gratuity/service charge: warns that a tip is included
/// and states whether it was computed on the pre- or post-tax amount.
struct GratuityBanner: View {
    let percent: Double?
    let amount: Double
    let basis: TipBasis?
    var symbol: String = "$"

    private var detail: String {
        let rate = percent.map { "\(Int($0))% " } ?? ""
        let amt = money(amount, symbol)
        switch basis {
        case .postTax: return "A \(rate)gratuity (\(amt)) is already on the bill — and it was charged on the post-tax total."
        case .preTax:  return "A \(rate)gratuity (\(amt)) is already on the bill, computed on the pre-tax subtotal."
        default:       return "A \(rate)gratuity (\(amt)) is already included in the total."
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.warn)
            VStack(alignment: .leading, spacing: 4) {
                Text("TIP ALREADY INCLUDED")
                    .font(.system(size: 13, weight: .heavy)).kerning(0.5)
                    .foregroundStyle(Theme.warn)
                Text(detail).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Theme.warnBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.warn.opacity(0.55), lineWidth: 2))
    }
}

/// Neutral info banner — currently the "no tip suggestions detected" state on the Review screen.
struct InfoBanner: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.inkSecondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                Text(detail).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
