//
//  LedgerService.swift
//  halfhazard
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Where ledger data comes from.
///
/// A protocol so `LedgerStore` can be exercised against real objects in memory rather than
/// against Firebase. It also gives dev mode somewhere to live that is not an `if` in twenty
/// methods, which is how the old `GroupViewModel` handled it.
protocol LedgerDataSource: Sendable {
    /// The ledger this user writes into, if they have one.
    func ledger(for userId: String) async throws -> Ledger?

    /// Streams the ledger's entries, newest first, and keeps streaming as they change.
    ///
    /// Everything in the old app was a one-shot `getDocuments()` with a `NotificationCenter`
    /// bus poking views to refetch, which meant the other person's changes only appeared if
    /// you happened to trigger a refresh. This is the replacement.
    func entries(in ledgerId: String) -> AsyncThrowingStream<[LedgerEntry], Error>

    /// The people on a ledger. Fetched once and held, rather than per row.
    ///
    /// Only ever returns the documents it is allowed to read, which in practice is the
    /// viewer's own: `users/{id}` is self-only. Names for the other person come from the
    /// ledger, not from here.
    func users(ids: [String]) async throws -> [User]

    /// Publishes a member's display name on the ledger, where the other member can read it.
    func recordName(_ name: String, for userId: String, in ledgerId: String) async throws

    func save(_ entry: LedgerEntry) async throws
    func delete(entryId: String, from ledgerId: String) async throws
}

/// The Firestore implementation.
///
/// Entries live at `ledgers/{id}/entries/{id}`: a rule that reads `resource.data.ledgerId`
/// can authorize fetching one entry but not querying for many, because Firestore has to
/// authorize a query before it has any documents in hand.
final class FirestoreLedgerService: LedgerDataSource {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func entriesCollection(_ ledgerId: String) -> CollectionReference {
        db.collection("ledgers").document(ledgerId).collection("entries")
    }

    func ledger(for userId: String) async throws -> Ledger? {
        let snapshot = try await db.collection("ledgers")
            .whereField("memberIds", arrayContains: userId)
            .getDocuments()

        // More than one would mean an unmerged migration; the oldest is the real one.
        return try snapshot.documents
            .map { try $0.data(as: Ledger.self) }
            .min { $0.createdAt < $1.createdAt }
    }

    func entries(in ledgerId: String) -> AsyncThrowingStream<[LedgerEntry], Error> {
        AsyncThrowingStream { continuation in
            let listener = entriesCollection(ledgerId)
                .order(by: "date", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }
                    do {
                        continuation.yield(try snapshot.documents.map { try $0.data(as: LedgerEntry.self) })
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func users(ids: [String]) async throws -> [User] {
        var users: [User] = []
        for id in ids {
            // Per id, because reading another member's profile is denied and that must not
            // take the viewer's own name — or the whole screen — down with it.
            guard let document = try? await db.collection("users").document(id).getDocument(),
                  let user = try? document.data(as: User.self) else { continue }
            users.append(user)
        }
        return users
    }

    func recordName(_ name: String, for userId: String, in ledgerId: String) async throws {
        try await db.collection("ledgers").document(ledgerId).setData(
            ["memberNames": [userId: name]], merge: true
        )
    }

    /// A one-shot read of the same collection the listener watches. For diagnostics.
    func loadEntriesOnce(ledgerId: String) async throws -> [LedgerEntry] {
        try await entriesCollection(ledgerId).getDocuments().documents.map {
            try $0.data(as: LedgerEntry.self)
        }
    }

    func save(_ entry: LedgerEntry) async throws {
        try entriesCollection(entry.ledgerId).document(entry.id).setData(from: entry)
    }

    func delete(entryId: String, from ledgerId: String) async throws {
        try await entriesCollection(ledgerId).document(entryId).delete()
    }
}
