//
//  AddExpenseSheet.swift
//  halfhazard
//

import SwiftUI

/// Records what was spent.
///
/// Who paid and how it splits are separate questions here. In the old form they were the
/// same question — `SplitType.currentUserOwes` meant both "they paid" and "I owe all of it"
/// — which is why the two could never be combined and why the labels read backwards for the
/// other person.
struct AddExpenseSheet: View {
    let store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var payerIsViewer = true
    @State private var share = Share.evenly
    @State private var isSaving = false

    /// How much of it the *viewer* ends up owing. Stated from one side so it cannot be
    /// ambiguous about whose half is whose.
    enum Share: String, CaseIterable, Identifiable {
        case evenly = "Split evenly"
        case allTheirs = "They owe it all"
        case allMine = "I owe it all"

        var id: String { rawValue }
    }

    private var amount: Money? {
        guard let money = Money(parsingDollars: amountText), money.cents > 0 else { return nil }
        return money
    }

    private var partnerName: String {
        store.partnerId.map { store.name(for: $0) } ?? "them"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $amountText)
                        .font(.title2.monospacedDigit())
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("What for?", text: $note)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Who paid") {
                    Picker("Who paid", selection: $payerIsViewer) {
                        Text("You").tag(true)
                        Text(partnerName).tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("How it splits") {
                    Picker("How it splits", selection: $share) {
                        ForEach(Share.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .labelsHidden()
                    #if os(macOS)
                    .pickerStyle(.radioGroup)
                    #endif

                    if let summary { Text(summary).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(amount == nil || isSaving)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 420)
    }

    /// Spells out the consequence before it is written, in the same words the feed will use.
    private var summary: String? {
        guard let amount, let partnerId = store.partnerId else { return nil }
        let owed = split(amount: amount, viewer: viewerId, partner: partnerId)
        let mine = owed[viewerId] ?? .zero
        return "You owe \(mine.formatted()) of \(amount.formatted())."
    }

    private var viewerId: String { store.viewerId }

    private func split(amount: Money, viewer: String, partner: String) -> [String: Money] {
        switch share {
        case .evenly:
            return (try? SplitAllocator.allocate(total: amount, rule: .equal, among: [viewer, partner])) ?? [:]
        case .allTheirs:
            return [partner: amount, viewer: .zero]
        case .allMine:
            return [viewer: amount, partner: .zero]
        }
    }

    private func rule(amount: Money, viewer: String, partner: String) -> SplitRule {
        share == .evenly ? .equal : .exact(split(amount: amount, viewer: viewer, partner: partner))
    }

    private func save() async {
        guard let amount, let partnerId = store.partnerId else { return }
        isSaving = true
        let entry = await store.addExpense(
            amount: amount,
            paidBy: payerIsViewer ? viewerId : partnerId,
            splitRule: rule(amount: amount, viewer: viewerId, partner: partnerId),
            note: note.isEmpty ? nil : note,
            date: date
        )
        isSaving = false
        if entry != nil { dismiss() }
    }
}
