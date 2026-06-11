//
//  EditRecordView.swift
//  TIP CALCULATOR
//
//  Sheet to edit details of a saved transaction (TipRecord).
//

import SwiftUI

struct EditRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HistoryStore.self) private var history
    
    let record: TipRecord
    
    @State private var restaurantName: String
    @State private var date: Date
    @State private var people: Int
    @State private var billShare: Double
    @State private var tipShare: Double
    @State private var savedShare: Double
    
    init(record: TipRecord) {
        self.record = record
        _restaurantName = State(initialValue: record.restaurantName ?? "")
        _date = State(initialValue: record.date)
        _people = State(initialValue: record.people)
        _billShare = State(initialValue: record.billShare)
        _tipShare = State(initialValue: record.tipShare)
        _savedShare = State(initialValue: record.savedShare)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 14) {
                        VStack(spacing: 0) {
                            textRow("Restaurant", $restaurantName)
                            Divider().overlay(Theme.ink.opacity(0.08))
                            dateRow("Date", $date)
                            Divider().overlay(Theme.ink.opacity(0.08))
                            peopleRow("People", $people)
                        }
                        .padding(.horizontal, 18)
                        .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        
                        SectionHeader("Shares (Per Person)").padding(.top, 6)
                        
                        VStack(spacing: 0) {
                            amountRow("Bill Share", $billShare, "$")
                            Divider().overlay(Theme.ink.opacity(0.08))
                            amountRow("Tip Share", $tipShare, "$")
                            Divider().overlay(Theme.ink.opacity(0.08))
                            amountRow("Saved Share", $savedShare, "$")
                        }
                        .padding(.horizontal, 18)
                        .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                        
                        CardButton(title: "Delete Transaction", systemImage: "trash.fill",
                                   background: Color.red.opacity(0.15), foreground: .red) {
                            history.delete(record)
                            dismiss()
                        }
                        .padding(.top, 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.ink)
                    .font(.system(size: 17, weight: .medium))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = TipRecord(
                            id: record.id,
                            date: date,
                            restaurantName: restaurantName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : restaurantName,
                            people: people,
                            billShare: billShare,
                            tipShare: tipShare,
                            savedShare: savedShare
                        )
                        history.upsert(updated)
                        dismiss()
                    }
                    .foregroundStyle(Theme.ink)
                    .font(.system(size: 17, weight: .bold))
                }
            }
        }
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
    
    private func dateRow(_ label: String, _ value: Binding<Date>) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            DatePicker("", selection: value, displayedComponents: .date)
                .labelsHidden()
                .tint(Theme.yellow)
        }
        .padding(.vertical, 10)
    }
    
    private func peopleRow(_ label: String, _ value: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
            Spacer()
            Text("\(value.wrappedValue) \(value.wrappedValue == 1 ? "person" : "people")")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink)
            Stepper("", value: value, in: 1...30).labelsHidden()
        }
        .padding(.vertical, 12)
    }
    
    private func amountRow(_ label: String, _ value: Binding<Double>, _ symbol: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
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
