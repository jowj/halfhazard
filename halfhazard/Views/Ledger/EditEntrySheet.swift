//
//  EditEntrySheet.swift
//  halfhazard
//

import SwiftUI

/// Corrects an entry that is already in the ledger.
///
/// Editing keeps the entry's identity — its id, when it was created and by whom — and
/// rewrites only what it says happened. The amounts owed are re-derived from the split rather
/// than edited directly, so a corrected total cannot leave the shares disagreeing with it,
/// which is how the old model drifted.
struct EditEntrySheet: View {
    let store: LedgerStore
    let entry: LedgerEntry
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String
    @State private var note: String
    @State private var date: Date
    @State private var payerIsViewer: Bool
    @State private var share: SplitShape
    @State private var isSaving = false

    init(store: LedgerStore, entry: LedgerEntry) {
        self.store = store
        self.entry = entry
        _amountText = State(initialValue: String(format: "%.2f", entry.amount.dollars))
        _note = State(initialValue: entry.note ?? "")
        _date = State(initialValue: entry.date)
        _payerIsViewer = State(initialValue: entry.solePayer == store.viewerId)
        _share = State(initialValue: SplitShape.of(entry, viewer: store.viewerId))
    }

    private var amount: Money? {
        guard let money = Money(parsingDollars: amountText), money.cents > 0 else { return nil }
        return money
    }

    private var partnerName: String {
        store.partnerId.map { store.name(for: $0) } ?? "them"
    }

    private var isSettlement: Bool { entry.kind == .settlement }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $amountText)
                        .font(.title2.monospacedDigit())
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField(isSettlement ? "Note" : "What for?", text: $note)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                if isSettlement {
                    Section {
                        Text(entry.settlementSentence(viewer: store.viewerId, name: store.name(for:)))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Who paid") {
                        Picker("Who paid", selection: $payerIsViewer) {
                            Text("You").tag(true)
                            Text(partnerName).tag(false)
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("How it splits") {
                        Picker("How it splits", selection: $share) {
                            ForEach(options) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .labelsHidden()
                        #if os(macOS)
                        .pickerStyle(.radioGroup)
                        #endif

                        if share == .asRecorded {
                            Text(recordedDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button("Delete this entry", role: .destructive) {
                        Task {
                            await store.delete(entry)
                            dismiss()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isSettlement ? "Edit settlement" : "Edit expense")
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

    /// "As recorded" is only worth offering when that is what the entry actually is.
    private var options: [SplitShape] {
        SplitShape.allCases.filter { $0 != .asRecorded || share == .asRecorded }
    }

    private var recordedDescription: String {
        entry.owedBy
            .sorted { $0.key < $1.key }
            .map { "\(store.name(for: $0.key)) \($0.value.formatted())" }
            .joined(separator: ", ")
    }

    private func save() async {
        guard let amount, let partnerId = store.partnerId else { return }
        isSaving = true

        var updated = entry
        updated.amount = amount
        updated.note = note.isEmpty ? nil : note
        updated.date = date

        if isSettlement {
            // Direction is not editable here; only how much changed hands. Deleting and
            // recording again is the honest way to reverse one.
            let payer = entry.solePayer ?? store.viewerId
            let recipient = entry.owedBy.keys.first ?? partnerId
            updated.paidBy = [payer: amount]
            updated.owedBy = [recipient: amount]
        } else {
            let payer = payerIsViewer ? store.viewerId : partnerId
            updated.paidBy = [payer: amount]

            switch share {
            case .evenly:
                updated.splitRule = .equal
            case .allViewer:
                updated.splitRule = .exact([store.viewerId: amount, partnerId: .zero])
            case .allPartner:
                updated.splitRule = .exact([store.viewerId: .zero, partnerId: amount])
            case .asRecorded:
                // Rescaled to whatever the amount is now, so the shares keep their ratio and
                // still add up. A percentage rule needs no help; an exact one does.
                if case .percentage = entry.splitRule {
                    updated.splitRule = entry.splitRule
                } else {
                    updated.splitRule = .exact(SplitAllocator.rescale(
                        entry.owedBy.mapValues(\.dollars), to: amount
                    ))
                }
            }

            let participants = store.ledger?.memberIds ?? Array(entry.owedBy.keys)
            guard let owed = try? SplitAllocator.allocate(
                total: amount,
                rule: updated.splitRule ?? .equal,
                among: participants
            ) else {
                isSaving = false
                return
            }
            updated.owedBy = owed
        }

        await store.update(updated)
        isSaving = false
        dismiss()
    }
}
