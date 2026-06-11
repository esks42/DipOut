//
//  PaywallView.swift
//  TIP CALCULATOR
//
//  Shown when the free-scan trial runs out. One-time lifetime unlock for unlimited scans.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var working = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }

                ScreenTitle("DipOut Pro")

                Text("You've used your free scans. Unlock unlimited receipts — one payment, forever.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)

                VStack(alignment: .leading, spacing: 14) {
                    feature("infinity", "Unlimited receipt scanning")
                    feature("chart.line.uptrend.xyaxis", "Keep your full savings history")
                    feature("bolt.fill", "Pays for itself in two dinners")
                }
                .padding(.vertical, 6)

                Spacer()

                Button(action: buy) {
                    Group {
                        if working {
                            ProgressView().tint(.black)
                        } else {
                            Text(store.product.map { "Unlock for \($0.displayPrice)" } ?? "Unlock Pro")
                                .font(.system(size: 19, weight: .bold))
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Theme.yellow, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(working || store.product == nil)

                Button("Restore purchase") {
                    Task { await store.restore(); if store.isPremium { dismiss() } }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .onChange(of: store.isPremium) { _, premium in
            if premium { dismiss() }
        }
    }

    private func buy() {
        working = true
        Task {
            await store.purchase()
            working = false
        }
    }

    private func feature(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.positive)
                .frame(width: 26)
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
    }
}
