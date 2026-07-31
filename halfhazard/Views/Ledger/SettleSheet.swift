//
//  SettleSheet.swift
//  halfhazard
//

import SwiftUI

/// Records money actually changing hands.
///
/// Settling writes a new entry rather than flipping a flag on old ones, so the amount is
/// editable: handing over part of what is owed leaves the rest outstanding, which the old
/// boolean could not express.
struct SettleSheet: View {
    let store: LedgerStore
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var isSaving = false

    private var outstanding: Money? { store.settlementNeeded?.amount }
    private var amount: Money? {
        guard let money = Money(parsingDollars: amountText), money.cents > 0 else { return nil }
        return money
    }

    private var direction: String {
        guard let needed = store.settlementNeeded else { return "Nothing to settle" }
        return needed.from == store.viewerId
            ? "You pay \(store.name(for: needed.to))"
            : "\(store.name(for: needed.from)) pays you"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Outstanding", value: outstanding?.formatted() ?? "—")
                    Text(direction)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Amount handed over") {
                    TextField("Amount", text: $amountText)
                        .font(.title2.monospacedDigit())
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Note", text: $note)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                if let amount, let outstanding, amount < outstanding {
                    Section {
                        Text("Leaves \((outstanding - amount).formatted()) outstanding.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settle up")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Record") { Task { await save() } }
                        .disabled(amount == nil || isSaving)
                }
            }
            .onAppear {
                if amountText.isEmpty, let outstanding {
                    amountText = String(format: "%.2f", outstanding.dollars)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 320)
    }

    private func save() async {
        guard let amount else { return }
        isSaving = true
        let entry = await store.settle(
            amount: amount,
            note: note.isEmpty ? nil : note,
            date: date
        )
        isSaving = false
        if entry != nil { dismiss() }
    }
}
