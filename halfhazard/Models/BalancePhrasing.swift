//
//  BalancePhrasing.swift
//  halfhazard
//

import Foundation

/// How the ledger describes itself in words.
///
/// Kept out of the views and tested, because getting this backwards is the defect the
/// rewrite exists to fix: the old `ExpenseRow` labelled the other person's expense "You
/// Paid", since the label keyed off a split type that meant "relative to whoever typed it".
/// Every phrase here takes the viewer explicitly.
extension Balance.Standing {

    /// The headline, e.g. "Laura owes you $32.10".
    func sentence(partnerName: String) -> String {
        if isSettled { return "You're square" }
        return viewerIsOwed
            ? "\(partnerName) owes you \(magnitude.formatted())"
            : "You owe \(partnerName) \(magnitude.formatted())"
    }

    /// A short form for tight spaces, e.g. "owed $32.10".
    var shortForm: String {
        if isSettled { return "settled" }
        return viewerIsOwed ? "owed \(magnitude.formatted())" : "owe \(magnitude.formatted())"
    }
}

extension LedgerEntry {

    /// Who put the money in, from the viewer's side: "You paid" or "Laura paid".
    func payerSentence(viewer: String, name: (String) -> String) -> String {
        guard let payer = solePayer else {
            return "Split payment"
        }
        return payer == viewer ? "You paid" : "\(name(payer)) paid"
    }

    /// What a settlement did, e.g. "Laura paid you $42.10".
    func settlementSentence(viewer: String, name: (String) -> String) -> String {
        guard let payer = solePayer, let recipient = owedBy.keys.first else {
            return "Settled \(amount.formatted())"
        }
        if payer == viewer {
            return "You paid \(name(recipient)) \(amount.formatted())"
        }
        return "\(name(payer)) paid you \(amount.formatted())"
    }

    /// What this entry did to the viewer's position, as a signed string.
    func deltaLabel(for viewer: String) -> String {
        let delta = self.delta(for: viewer)
        if delta.isZero { return "—" }
        return delta.isNegative
            ? "-\(delta.magnitude.formatted())"
            : "+\(delta.magnitude.formatted())"
    }
}
