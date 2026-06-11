//
//  Theme.swift
//  TIP CALCULATOR
//
//  Flat, warm-minimal design system: one accent (yellow), bold black numerals,
//  rounded cards on a greige background. Colour is used to carry meaning.
//

import SwiftUI

enum Theme {
    // Surfaces
    static let bg      = Color(red: 0.906, green: 0.898, blue: 0.871)   // warm greige
    static let surface = Color(red: 0.847, green: 0.839, blue: 0.812)   // gray card
    static let yellow  = Color(red: 0.957, green: 0.804, blue: 0.247)   // accent / hero

    // Ink
    static let ink          = Color(red: 0.094, green: 0.094, blue: 0.090)
    static let inkSecondary = Color.black.opacity(0.42)

    // Semantic (verdict only)
    static let warn   = Color(red: 0.70, green: 0.46, blue: 0.05)
    static let warnBg = Color(red: 0.984, green: 0.886, blue: 0.690)   // filled amber for strong warnings
    static let good   = Color(red: 0.27, green: 0.52, blue: 0.32)

    // Brand "positive" (Ethan brand v2.2): #059669 on #D1FAE5
    static let positive   = Color(red: 0.020, green: 0.588, blue: 0.412)
    static let positiveBg = Color(red: 0.820, green: 0.980, blue: 0.898)

    static let radius: CGFloat = 28
}

/// Big bottom-left numeral block: "$ 4.77 Tip" — the signature stat from the reference.
struct StatCard: View {
    let prefix: String
    let value: String
    let label: String
    var background: Color = Theme.surface
    var valueColor: Color = Theme.ink
    var minHeight: CGFloat = 150

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(prefix)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(valueColor.opacity(0.8))
                .fixedSize()
            Text(value)
                .font(.system(size: 62, weight: .black))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .layoutPriority(1)
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, 3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .bottomLeading)
        .padding(22)
        .background(background, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}

/// Full-width tappable card used for primary/secondary actions.
struct CardButton: View {
    let title: String
    let systemImage: String
    var background: Color = Theme.surface
    var foreground: Color = Theme.ink
    var minHeight: CGFloat = 64
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage).font(.system(size: 20, weight: .semibold))
                Text(title).font(.system(size: 19, weight: .semibold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Bold in-content screen title (top-left, like the reference).
struct ScreenTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .black))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
            Spacer()
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) { self.init(title: title) { EmptyView() } }
}
