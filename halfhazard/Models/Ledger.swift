//
//  Ledger.swift
//  halfhazard
//

import Foundation

/// The shared book two people write into.
///
/// There is exactly one of these per pairing and it is never shown in the UI — it
/// exists so Firestore rules can answer "may this user read this entry?". It replaces
/// the old `Group`, which surfaced a whole navigation layer for a concept with one instance.
struct Ledger: Identifiable, Hashable, Codable {
    let id: String
    var memberIds: [String]

    /// Display names, each written by the person it belongs to.
    ///
    /// Denormalised on purpose: `users/{id}` is readable only by that user, so one member
    /// cannot read the other's profile to find their name. Rather than open those documents
    /// up, each client writes its own name here, where both already have access.
    var memberNames: [String: String]?

    let createdAt: Date

    init(
        id: String,
        memberIds: [String],
        memberNames: [String: String]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.memberIds = memberIds
        self.memberNames = memberNames
        self.createdAt = createdAt
    }

    func contains(_ userId: String) -> Bool {
        memberIds.contains(userId)
    }

    /// The other member, for the two-person case the app is built around.
    func partner(of userId: String) -> String? {
        memberIds.first { $0 != userId }
    }
}
