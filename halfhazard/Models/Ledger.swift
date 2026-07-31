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
    let createdAt: Date

    init(id: String, memberIds: [String], createdAt: Date = Date()) {
        self.id = id
        self.memberIds = memberIds
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
