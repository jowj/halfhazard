//
//  Balance.swift
//  halfhazard
//

import Foundation

/// The one place that answers "who owes whom".
///
/// Previously this was computed two different ways — `GroupViewModel` keyed off the
/// expense creator while `ExpenseRow` keyed off the payments map — so the sidebar and
/// the rows could disagree. Every balance in the app now comes from here.
enum Balance {
    /// Net position across the whole history. Positive means the user is owed money.
    static func net(for userId: String, in entries: [LedgerEntry]) -> Money {
        entries.reduce(Money.zero) { $0 + $1.delta(for: userId) }
    }

    static func all(for members: [String], in entries: [LedgerEntry]) -> [String: Money] {
        members.reduce(into: [:]) { result, member in
            result[member] = net(for: member, in: entries)
        }
    }

    /// How a two-person ledger stands, from `viewer`'s side.
    static func standing(
        viewer: String,
        partner: String,
        in entries: [LedgerEntry]
    ) -> Standing {
        Standing(amount: net(for: viewer, in: entries), partner: partner)
    }

    /// A settled-up balance expressed as the entry that would clear it.
    /// Returns nil when nothing is owed in either direction.
    static func settlementNeeded(
        viewer: String,
        partner: String,
        in entries: [LedgerEntry]
    ) -> (from: String, to: String, amount: Money)? {
        let position = net(for: viewer, in: entries)
        if position.isZero { return nil }
        return position.isNegative
            ? (from: viewer, to: partner, amount: position.magnitude)
            : (from: partner, to: viewer, amount: position.magnitude)
    }

    /// A balance with enough context to phrase itself for one side of the ledger.
    struct Standing: Hashable {
        /// Positive means the viewer is owed, negative means the viewer owes.
        let amount: Money
        let partner: String

        var isSettled: Bool { amount.isZero }
        var viewerIsOwed: Bool { amount.cents > 0 }
        var magnitude: Money { amount.magnitude }
    }
}
