//
//  LedgerStore.swift
//  halfhazard
//

import Foundation

/// The app's single source of truth for the ledger.
///
/// One store, one listener, one balance. The old app had `GroupViewModel` and
/// `ExpenseViewModel` computing balances two different ways off one-shot fetches, kept
/// roughly in sync by a hand-rolled `NotificationCenter` bus. Here the entries arrive from a
/// snapshot listener and everything else is derived, so there is nothing to keep in sync:
/// the other person's changes land on their own.
@MainActor
@Observable
final class LedgerStore {
    private let source: LedgerDataSource
    /// Whose side of the ledger this is. Every label in the UI is phrased against it, so it
    /// is stated once here rather than implied by who happened to create a row.
    let viewerId: String

    /// Held outside the actor so `deinit`, which is not main-actor isolated, can still stop
    /// the listener. Dropping the store has to drop its Firestore listener with it.
    private final class ListenerBox: @unchecked Sendable {
        var task: Task<Void, Never>?
        func cancel() { task?.cancel(); task = nil }
    }
    private let listener = ListenerBox()

    private(set) var ledger: Ledger?
    private(set) var entries: [LedgerEntry] = []
    /// Both people, loaded once. `ExpenseRow` used to fetch a user per row just to show a name.
    private(set) var users: [String: User] = [:]
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    init(source: LedgerDataSource, viewerId: String) {
        self.source = source
        self.viewerId = viewerId
    }

    deinit {
        listener.cancel()
    }

    // MARK: - Derived

    var partnerId: String? { ledger?.partner(of: viewerId) }

    /// Where the viewer stands. The only balance in the app.
    var standing: Balance.Standing {
        Balance.Standing(amount: Balance.net(for: viewerId, in: entries), partner: partnerId ?? "")
    }

    /// What would square things up, or nil when nothing is owed.
    var settlementNeeded: (from: String, to: String, amount: Money)? {
        guard let partnerId else { return nil }
        return Balance.settlementNeeded(viewer: viewerId, partner: partnerId, in: entries)
    }

    func name(for userId: String) -> String {
        if userId == viewerId { return "You" }
        if let published = ledger?.memberNames?[userId], !published.isEmpty { return published }
        if let user = users[userId] { return Self.name(of: user) }
        // Until the other person opens the app once, there is nothing readable to call them:
        // their profile document is theirs alone to read.
        return "Them"
    }

    private static func name(of user: User) -> String {
        if let displayName = user.displayName, !displayName.isEmpty { return displayName }
        return user.email.components(separatedBy: "@").first ?? "Them"
    }

    /// Publishes the viewer's own name onto the ledger so the other person can see it.
    private func publishOwnName(in ledger: Ledger) async {
        guard let me = users[viewerId] else { return }
        let mine = Self.name(of: me)
        guard ledger.memberNames?[viewerId] != mine else { return }
        try? await source.recordName(mine, for: viewerId, in: ledger.id)
    }

    /// Entries grouped into day-sized buckets, newest first, for a sectioned feed.
    var entriesByDay: [(day: Date, entries: [LedgerEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    // MARK: - Lifecycle

    /// Finds the viewer's ledger, loads both people, and starts listening.
    /// Safe to call repeatedly; a second call replaces the first listener.
    func start() async {
        listener.cancel()
        isLoading = true
        errorMessage = nil

        do {
            guard let ledger = try await source.ledger(for: viewerId) else {
                self.ledger = nil
                self.entries = []
                isLoading = false
                return
            }
            self.ledger = ledger

            // Names are decoration. Failing to load them must never cost the ledger itself —
            // the first version of this treated a denied read of the *other* member's
            // profile as fatal, and the screen came up empty with a permissions error on a
            // ledger whose 80 entries had loaded perfectly well.
            do {
                let people = try await source.users(ids: ledger.memberIds)
                users = Dictionary(people.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
                await publishOwnName(in: ledger)
            } catch {
                users = [:]
            }

            listener.task = Task { [weak self, source] in
                do {
                    for try await entries in source.entries(in: ledger.id) {
                        guard !Task.isCancelled else { return }
                        await self?.received(entries)
                    }
                } catch {
                    await self?.failed(error)
                }
            }
        } catch {
            failed(error)
        }
    }

    func stop() {
        listener.cancel()
    }

    private func received(_ entries: [LedgerEntry]) {
        // The query orders by date, but two entries on the same day need a stable tiebreak
        // or the feed reshuffles itself on every snapshot.
        self.entries = entries.sorted {
            $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date
        }
        isLoading = false
        errorMessage = nil
    }

    private func failed(_ error: Error) {
        errorMessage = error.localizedDescription
        isLoading = false
    }

    // MARK: - Writing

    /// Records an expense. `owedBy` is derived from the rule rather than passed in, so the
    /// stored amounts and the stated intent cannot disagree.
    @discardableResult
    func addExpense(
        amount: Money,
        paidBy payer: String,
        splitRule: SplitRule = .equal,
        note: String? = nil,
        category: String? = nil,
        date: Date = Date(),
        id: String = UUID().uuidString
    ) async -> LedgerEntry? {
        guard let ledger else {
            errorMessage = "There is no ledger to write to yet."
            return nil
        }

        do {
            let entry = try LedgerEntry.expense(
                id: id,
                ledgerId: ledger.id,
                amount: amount,
                paidBy: payer,
                splitRule: splitRule,
                among: ledger.memberIds,
                note: note,
                category: category,
                date: date,
                createdBy: viewerId
            )
            try await source.save(entry)
            return entry
        } catch {
            failed(error)
            return nil
        }
    }

    /// Records money changing hands. Settling is an entry like any other, never a flag on
    /// old rows, so the history stays true and a partial payment is just a smaller amount.
    @discardableResult
    func settle(
        amount: Money? = nil,
        note: String? = nil,
        date: Date = Date(),
        id: String = UUID().uuidString
    ) async -> LedgerEntry? {
        guard let ledger, let needed = settlementNeeded else {
            errorMessage = "Nothing to settle."
            return nil
        }

        let entry = LedgerEntry.settlement(
            id: id,
            ledgerId: ledger.id,
            from: needed.from,
            to: needed.to,
            amount: amount ?? needed.amount,
            note: note,
            date: date,
            createdBy: viewerId
        )
        do {
            try await source.save(entry)
            return entry
        } catch {
            failed(error)
            return nil
        }
    }

    func update(_ entry: LedgerEntry) async {
        do {
            try await source.save(entry)
        } catch {
            failed(error)
        }
    }

    func delete(_ entry: LedgerEntry) async {
        do {
            try await source.delete(entryId: entry.id, from: entry.ledgerId)
        } catch {
            failed(error)
        }
    }
}
