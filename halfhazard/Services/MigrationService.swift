//
//  MigrationService.swift
//  halfhazard
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Moves a group's expenses into the ledger.
///
/// Reads `expenses`, writes `entries` and `ledgers`. It never writes to `expenses` or
/// `groups` — the old collections stay exactly as they are, so a bad migration costs a
/// delete of `entries` and nothing else.
///
/// The order is always: `dryRun`, read the report, then `commit`. `commit` refuses a report
/// that is not clean unless it is told explicitly to go anyway.
final class MigrationService {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    enum MigrationError: LocalizedError {
        case notAuthenticated
        case notAMember(groupId: String)
        case reportNotClean(MigrationReport)
        case readDenied(collection: String, underlying: Error)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You need to be signed in to migrate."
            case .notAMember(let groupId):
                return "You are not a member of group \(groupId)."
            case .reportNotClean(let report):
                return "Migration dry run did not come back clean:\n\(report.summary)"
            case .readDenied(let collection, let underlying):
                return "Reading `\(collection)` failed: \(underlying.localizedDescription)"
            }
        }
    }

    // MARK: - Reading

    /// Entries live under their ledger rather than in a top-level collection.
    ///
    /// A security rule that reads `resource.data.ledgerId` can authorize fetching one entry
    /// but not querying for many: Firestore has to authorize a query before it has any
    /// documents to look at. With the ledger id in the path, the same rule covers both.
    func entries(in ledgerId: String) -> CollectionReference {
        db.collection("ledgers").document(ledgerId).collection("entries")
    }

    /// Every expense in a group, oldest first.
    ///
    /// Deliberately unordered in the query and sorted in memory: the old ordered query needs
    /// a composite index, and a migration should not be the thing that discovers it is missing.
    func loadLegacyExpenses(groupId: String) async throws -> [Expense] {
        let snapshot = try await db.collection("expenses")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments()

        return try snapshot.documents
            .map { try $0.data(as: Expense.self) }
            .sorted { $0.createdAt.dateValue() < $1.createdAt.dateValue() }
    }

    // MARK: - What to migrate

    /// Which old groups become which ledger.
    ///
    /// Not every group deserves to become a ledger, and more than one can become the same
    /// one: this account has two groups holding the two halves of the same relationship, one
    /// picking up the day the other stopped, plus a couple of solo scratch groups. The
    /// single-screen UI shows one ledger, so which groups fold into it is a decision, not
    /// something to infer.
    struct Target {
        let ledgerId: String
        let groupIds: [String]

        init(ledgerId: String? = nil, groupIds: [String]) {
            self.ledgerId = ledgerId ?? groupIds.first ?? ""
            self.groupIds = groupIds
        }
    }

    /// Every group the signed-in user belongs to, each as its own ledger.
    func allGroupsAsSeparateLedgers() async throws -> [Target] {
        guard let currentUser = Auth.auth().currentUser else {
            throw MigrationError.notAuthenticated
        }

        let snapshot = try await db.collection("groups")
            .whereField("memberIds", arrayContains: currentUser.uid)
            .getDocuments()

        return try snapshot.documents
            .map { try $0.data(as: Group.self).id }
            .sorted()
            .map { Target(groupIds: [$0]) }
    }

    /// Loads the groups behind a target and checks the user is in all of them.
    private func groups(for target: Target) async throws -> [Group] {
        guard let currentUser = Auth.auth().currentUser else {
            throw MigrationError.notAuthenticated
        }

        var groups: [Group] = []
        for groupId in target.groupIds {
            let group = try await db.collection("groups").document(groupId).getDocument(as: Group.self)
            guard group.memberIds.contains(currentUser.uid) else {
                throw MigrationError.notAMember(groupId: groupId)
            }
            groups.append(group)
        }
        return groups
    }

    /// Builds the plan for a target: every source group's expenses, against the union of
    /// their members. Legacy document ids stay as entry ids, and they are unique across
    /// groups, so folding several groups together cannot collide.
    private func plan(for target: Target) async throws -> MigrationPlan {
        let groups = try await groups(for: target)
        var expenses: [Expense] = []
        for group in groups {
            expenses.append(contentsOf: try await loadLegacyExpenses(groupId: group.id))
        }

        let members = groups.reduce(into: [String]()) { members, group in
            for member in group.memberIds where !members.contains(member) { members.append(member) }
        }
        return LedgerMigrator.plan(expenses: expenses, ledgerId: target.ledgerId, members: members)
    }

    // MARK: - Dry run

    /// Reports what migrating a target would do. Writes nothing.
    func dryRun(target: Target) async throws -> MigrationReport {
        MigrationReport.dryRun(plan: try await plan(for: target))
    }

    /// Reports what migrating a single group as its own ledger would do.
    func dryRun(groupId: String) async throws -> MigrationReport {
        try await dryRun(target: Target(groupIds: [groupId]))
    }

    /// Dry runs every group the signed-in user belongs to, each as its own ledger.
    func dryRunAll() async throws -> [MigrationReport] {
        var reports: [MigrationReport] = []
        for target in try await allGroupsAsSeparateLedgers() {
            reports.append(try await dryRun(target: target))
        }
        return reports
    }

    // MARK: - Commit

    /// Writes the plan's ledger and entries.
    ///
    /// Idempotent: entry ids are derived from the legacy documents, so running it twice
    /// overwrites the same documents rather than doubling the ledger.
    ///
    /// - Parameter force: commit despite a report that is not clean. Only for a report whose
    ///   issues have been read and understood.
    @discardableResult
    func commit(report: MigrationReport, force: Bool = false) async throws -> Int {
        guard Auth.auth().currentUser != nil else { throw MigrationError.notAuthenticated }
        guard report.isClean || force else { throw MigrationError.reportNotClean(report) }

        let plan = report.plan

        // Awaited on purpose: the security rule on `entries` reads the ledger document to
        // decide whether the writer is a member, so the ledger has to be on the server
        // before any entry referring to it is. The non-async `setData(from:)` would return
        // as soon as the write was queued locally and the batch below could beat it there.
        let ledger = try Firestore.Encoder().encode(plan.ledger)
        try await db.collection("ledgers").document(plan.ledgerId).setData(ledger, merge: true)

        // Firestore caps a batch at 500 writes; chunked well under it.
        let collection = entries(in: plan.ledgerId)
        for chunk in stride(from: 0, to: plan.entries.count, by: 400) {
            let batch = db.batch()
            for entry in plan.entries[chunk..<min(chunk + 400, plan.entries.count)] {
                try batch.setData(from: entry, forDocument: collection.document(entry.id))
            }
            try await batch.commit()
        }

        return plan.entries.count
    }

    // MARK: - Inspecting

    /// Dumps a legacy expense exactly as it is stored, next to what the migration makes of it.
    ///
    /// For deciding what to do about a document the dry run flagged. The stored fields are
    /// printed raw — not through `Expense`, whose decoder fills in defaults for anything
    /// missing and would hide the very thing being investigated.
    func inspect(expenseId: String) async throws -> String {
        guard Auth.auth().currentUser != nil else { throw MigrationError.notAuthenticated }

        let document = try await db.collection("expenses").document(expenseId).getDocument()
        guard let raw = document.data() else { return "\(expenseId): no such document" }

        var lines = ["Expense \(expenseId)", "  stored:"]
        for key in raw.keys.sorted() {
            lines.append("    \(key): \(raw[key] ?? "nil")")
        }

        let expense = try document.data(as: Expense.self)
        let group = try await db.collection("groups").document(expense.groupId).getDocument(as: Group.self)
        let plan = LedgerMigrator.plan(expenses: [expense], ledgerId: group.id, members: group.memberIds)

        lines.append("  group \(group.id): \(group.memberIds.joined(separator: ", "))")
        lines.append("  migrates to:")
        for entry in plan.entries {
            lines.append("    \(entry.kind.rawValue) \(entry.amount.formatted())"
                + " paidBy \(entry.paidBy.map { "\($0.key)=\($0.value.formatted())" }.sorted().joined(separator: " "))"
                + " owedBy \(entry.owedBy.map { "\($0.key)=\($0.value.formatted())" }.sorted().joined(separator: " "))")
            for member in group.memberIds.sorted() {
                lines.append("      \(member) net \(entry.delta(for: member).formatted())")
            }
        }
        for issue in plan.issues {
            lines.append("  issue: \(issue.message)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Audit

    /// Every entry written for a ledger, read back from the server.
    func loadEntries(ledgerId: String) async throws -> [LedgerEntry] {
        let snapshot = try await entries(in: ledgerId).getDocuments()

        return try snapshot.documents
            .map { try $0.data(as: LedgerEntry.self) }
            .sorted { $0.date < $1.date }
    }

    /// Reads back what was written and checks it against what should have been.
    ///
    /// The dry run says what the migration *would* do; this says what it *did*. Worth having
    /// separately because a commit can be half-applied — a batch can fail on its own — and a
    /// migration that silently wrote nothing looks exactly like one that succeeded.
    func audit(target: Target) async throws -> MigrationAudit {
        let expected = try await plan(for: target)

        // Named separately so a permission failure says which collection refused. The two
        // rules differ, and "insufficient permissions" on its own does not say which one.
        let ledgerExists: Bool
        do {
            ledgerExists = try await db.collection("ledgers")
                .document(target.ledgerId).getDocument().exists
        } catch {
            throw MigrationError.readDenied(collection: "ledgers", underlying: error)
        }

        let entries: [LedgerEntry]
        do {
            entries = try await loadEntries(ledgerId: target.ledgerId)
        } catch {
            throw MigrationError.readDenied(collection: "entries", underlying: error)
        }

        return MigrationAudit(
            plan: expected,
            written: entries,
            ledgerDocumentExists: ledgerExists
        )
    }

    func audit(groupId: String) async throws -> MigrationAudit {
        try await audit(target: Target(groupIds: [groupId]))
    }

    /// Audits every group the signed-in user belongs to.
    func auditAll() async throws -> [MigrationAudit] {
        var audits: [MigrationAudit] = []
        for target in try await allGroupsAsSeparateLedgers() {
            audits.append(try await audit(target: target))
        }
        return audits
    }

    /// Dry run and commit in one call, for the common case where everything is clean.
    @discardableResult
    func migrate(groupId: String, force: Bool = false) async throws -> MigrationReport {
        let report = try await dryRun(groupId: groupId)
        try await commit(report: report, force: force)
        return report
    }
}
