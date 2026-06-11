//
//  TipHistory.swift
//  TIP CALCULATOR
//
//  Persisted record of saved receipts and the tip overcharge avoided on each.
//

import SwiftUI

/// One saved receipt, recorded on a per-person basis (your share of the bill, not the whole table).
struct TipRecord: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var restaurantName: String?
    var people: Int
    /// Per-person share of subtotal + tax (pre-tip).
    var billShare: Double
    /// Per-person tip paid.
    var tipShare: Double
    /// Per-person amount saved by tipping pre-tax (0 when the suggestion was already fair).
    var savedShare: Double
}

@Observable
final class HistoryStore {
    private(set) var records: [TipRecord] = []
    private let key = "tip_history_v2"

    init() { load() }

    /// Insert a record, or update the existing one with the same id.
    func upsert(_ record: TipRecord) {
        if let i = records.firstIndex(where: { $0.id == record.id }) {
            records[i] = record
        } else {
            records.insert(record, at: 0)
        }
        persist()
    }

    /// Delete a record.
    func delete(_ record: TipRecord) {
        records.removeAll(where: { $0.id == record.id })
        persist()
    }

    /// Total per-person saved across records on or after `date`.
    func saved(since date: Date) -> Double {
        records.filter { $0.date >= date }.reduce(0) { $0 + $1.savedShare }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TipRecord].self, from: data) else { return }
        records = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
