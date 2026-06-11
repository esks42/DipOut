//
//  HistoryView.swift
//  TIP CALCULATOR
//
//  Saved-tips history: how much tipping pre-tax has saved over several time windows.
//

import SwiftUI

struct HistoryView: View {
    @Environment(HistoryStore.self) private var history
    var onNewScan: () -> Void = {}
    @State private var selected = 0
    @State private var editingRecord: TipRecord?

    private let cal = Calendar.current
    private var now: Date { .now }

    private struct Period: Identifiable {
        let id = UUID()
        let label: String
        let since: Date
    }

    private var periods: [Period] {
        [Period(label: "This month", since: startOfMonth),
         Period(label: "Last 3 months", since: monthsAgo(3)),
         Period(label: "Last 6 months", since: monthsAgo(6)),
         Period(label: "This year", since: startOfYear)]
    }

    private var startOfMonth: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
    }
    private var startOfYear: Date {
        cal.date(from: cal.dateComponents([.year], from: now)) ?? now
    }
    private func monthsAgo(_ n: Int) -> Date {
        cal.date(byAdding: .month, value: -n, to: now) ?? now
    }

    var body: some View {
        let period = periods[selected]
        let inPeriod = history.records.filter { $0.date >= period.since }

        return ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        ScreenTitle("Saved")
                        NewScanButton(action: onNewScan)
                    }

                    StatCard(prefix: "$", value: amt(history.saved(since: period.since)),
                             label: period.label,
                             background: Theme.positiveBg.opacity(0.6), valueColor: Theme.positive, minHeight: 76)

                    Text("Your share — what you personally saved by tipping pre-tax.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(periods.indices, id: \.self) { i in
                            periodRow(periods[i], isSelected: i == selected) { selected = i }
                            if i < periods.count - 1 {
                                Divider().overlay(Theme.ink.opacity(0.08))
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))

                    SectionHeader(period.label).padding(.top, 6)

                    if history.records.isEmpty {
                        emptyText("No saved receipts yet. Calculate a fair tip and it'll be saved here automatically.")
                    } else if inPeriod.isEmpty {
                        emptyText("No saved receipts in this period.")
                    } else {
                        ForEach(inPeriod) { record in
                            recordRow(record)
                        }
                    }
                }
                .padding(20)
            }
        }
        .sheet(item: $editingRecord) { record in
            EditRecordView(record: record)
        }
    }

    private func periodRow(_ p: Period, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(p.label)
                    .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Theme.positive : Theme.ink)
                Spacer()
                Text(money(history.saved(since: p.since)))
                    .font(.system(size: 18, weight: .bold)).monospacedDigit()
                    .foregroundStyle(isSelected ? Theme.positive : Theme.ink)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isSelected ? Theme.positive : Theme.inkSecondary.opacity(0.5))
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func recordRow(_ r: TipRecord) -> some View {
        Button {
            editingRecord = r
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    let name = (r.restaurantName == nil || r.restaurantName!.trimmingCharacters(in: .whitespaces).isEmpty) ? "Unknown" : r.restaurantName!
                    Text(name)
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(r.date, format: .dateTime.month().day().year())
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.inkSecondary)
                    Text("\(money(r.billShare)) incl. tax · \(money(r.tipShare)) tip · ÷\(r.people)")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                if r.savedShare > 0 {
                    Text("saved \(money(r.savedShare))")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.positive)
                } else {
                    Text("fair").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.inkSecondary)
            .padding(.horizontal, 4)
    }

    private func amt(_ v: Double) -> String { amountString(v) }
}
