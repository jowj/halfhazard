//
//  EntryRow.swift
//  halfhazard
//

import SwiftUI

/// One line in the feed.
///
/// Everything it shows comes from the entry and the viewer passed in — there is no fetch
/// here. The old row hit Firestore once per row just to turn a user id into a name.
struct EntryRow: View {
    let entry: LedgerEntry
    let viewerId: String
    let name: (String) -> String

    private var delta: Money { entry.delta(for: viewerId) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.amount.formatted())
                    .font(.body.monospacedDigit())
                Text(entry.deltaLabel(for: viewerId))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(deltaColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: some View {
        Image(systemName: entry.kind == .settlement ? "arrow.left.arrow.right" : "cart")
            .font(.callout)
            .foregroundStyle(entry.kind == .settlement ? Color.accentColor : .secondary)
            .frame(width: 28, height: 28)
            .background(.quaternary, in: Circle())
    }

    private var title: String {
        if let note = entry.note, !note.isEmpty { return note }
        return entry.kind == .settlement ? "Settled up" : "Expense"
    }

    private var subtitle: String {
        entry.kind == .settlement
            ? entry.settlementSentence(viewer: viewerId, name: name)
            : entry.payerSentence(viewer: viewerId, name: name)
    }

    private var deltaColor: Color {
        if delta.isZero { return .secondary }
        return delta.isNegative ? .red : .green
    }
}

#Preview {
    let entries = [
        try! LedgerEntry.expense(
            id: "1", ledgerId: "l", amount: Money(cents: 8420), paidBy: "me",
            splitRule: .equal, among: ["me", "them"], note: "Groceries", createdBy: "me"
        ),
        try! LedgerEntry.expense(
            id: "2", ledgerId: "l", amount: Money(cents: 1250), paidBy: "them",
            splitRule: .equal, among: ["me", "them"], note: "Coffee", createdBy: "them"
        ),
        LedgerEntry.settlement(
            id: "3", ledgerId: "l", from: "them", to: "me",
            amount: Money(cents: 3585), createdBy: "them"
        )
    ]
    return List(entries) { entry in
        EntryRow(entry: entry, viewerId: "me") { $0 == "me" ? "You" : "Laura" }
    }
}
