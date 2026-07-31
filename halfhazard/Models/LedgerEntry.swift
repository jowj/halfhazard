//
//  LedgerEntry.swift
//  halfhazard
//

import Foundation

enum EntryKind: String, Codable, Hashable {
    /// Somebody spent money that two people share.
    case expense
    /// Somebody handed money to the other person to square up.
    case settlement
}

/// One line in the shared book.
///
/// Expenses and settlements share a shape on purpose: both record who put money in
/// (`paidBy`) and who the money was for (`owedBy`). That lets `Balance` sum over
/// everything with no per-kind branching, and makes settling a normal entry rather
/// than a flag flipped on old rows. `kind` only changes how a row is drawn.
///
/// Entries are append-only in spirit: settling adds a line, it never rewrites history.
struct LedgerEntry: Identifiable, Hashable, Codable {
    let id: String
    let ledgerId: String
    var kind: EntryKind

    /// Total spent, or the amount handed over for a settlement.
    var amount: Money
    /// Who fronted the money. Sums to `amount`.
    var paidBy: [String: Money]
    /// Who the money was for. Sums to `amount`.
    var owedBy: [String: Money]

    var note: String?
    var category: String?
    /// Retained so the edit screen can show intent. Nil for settlements.
    var splitRule: SplitRule?

    /// When it happened, which is not always when it was typed in.
    var date: Date
    let createdAt: Date
    let createdBy: String

    // MARK: - Derived

    /// What this entry does to a person's balance: positive means they are owed.
    func delta(for userId: String) -> Money {
        (paidBy[userId] ?? .zero) - (owedBy[userId] ?? .zero)
    }

    var participants: Set<String> {
        Set(paidBy.keys).union(owedBy.keys)
    }

    /// Both sides must account for the full amount or balances silently drift.
    var isBalanced: Bool {
        paidBy.values.total == amount && owedBy.values.total == amount
    }

    /// The single payer, when there is exactly one. Both entry kinds normally have one.
    var solePayer: String? {
        let payers = paidBy.filter { !$0.value.isZero }
        return payers.count == 1 ? payers.first?.key : nil
    }

    // MARK: - Construction

    /// Builds an expense, deriving what each person owes from the split rule.
    static func expense(
        id: String,
        ledgerId: String,
        amount: Money,
        paidBy payer: String,
        splitRule: SplitRule,
        among participants: [String],
        note: String? = nil,
        category: String? = nil,
        date: Date = Date(),
        createdAt: Date = Date(),
        createdBy: String
    ) throws -> LedgerEntry {
        let owed = try SplitAllocator.allocate(
            total: amount,
            rule: splitRule,
            among: participants
        )
        return LedgerEntry(
            id: id,
            ledgerId: ledgerId,
            kind: .expense,
            amount: amount,
            paidBy: [payer: amount],
            owedBy: owed,
            note: note,
            category: category,
            splitRule: splitRule,
            date: date,
            createdAt: createdAt,
            createdBy: createdBy
        )
    }

    /// Builds a settlement: money moving from one person to another to square up.
    static func settlement(
        id: String,
        ledgerId: String,
        from payer: String,
        to recipient: String,
        amount: Money,
        note: String? = nil,
        date: Date = Date(),
        createdAt: Date = Date(),
        createdBy: String
    ) -> LedgerEntry {
        LedgerEntry(
            id: id,
            ledgerId: ledgerId,
            kind: .settlement,
            amount: amount,
            paidBy: [payer: amount],
            owedBy: [recipient: amount],
            note: note,
            category: nil,
            splitRule: nil,
            date: date,
            createdAt: createdAt,
            createdBy: createdBy
        )
    }
}
