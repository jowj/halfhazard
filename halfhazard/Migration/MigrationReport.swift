//
//  MigrationReport.swift
//  halfhazard
//

import Foundation

/// The balances the old app showed, reproduced exactly — bugs included.
///
/// The point is not to be right. It is to be a faithful copy of what the two shipped
/// calculations produced, so the dry run can prove the ledger agrees with what people were
/// actually looking at, and show where the old two disagreed with each other.
enum LegacyBalance {

    /// `GroupViewModel.calculateUserBalance`: assumes whoever created an expense paid all of
    /// it, ignores the `payments` map entirely, and skips settled expenses.
    static func sidebarStyle(for userId: String, in expenses: [Expense]) -> Double {
        expenses.filter { !$0.settled }.reduce(0.0) { total, expense in
            let paid = expense.createdBy == userId ? expense.amount : 0
            return total + paid - (expense.splits[userId] ?? 0)
        }
    }

    /// `ExpenseRow`: uses the `payments` map when it exists and falls back to the creator and
    /// split type when it does not. Summed over unsettled expenses to be comparable.
    static func rowStyle(for userId: String, in expenses: [Expense]) -> Double {
        expenses.filter { !$0.settled }.reduce(0.0) { total, expense in
            let paid: Double
            if !expense.payments.isEmpty {
                paid = expense.payments[userId] ?? 0
            } else if userId == expense.createdBy {
                switch expense.splitType {
                // The legacy fallback credited nobody here, which is exactly the hole the
                // migration fills by naming the other person as the payer.
                case .currentUserOwes: paid = 0
                case .currentUserOwed, .equal, .custom: paid = expense.amount
                }
            } else {
                paid = 0
            }
            return total + paid - (expense.splits[userId] ?? 0)
        }
    }
}

/// A dry run: what the migration would write, and whether the numbers survive it.
///
/// Nothing is committed until this comes back clean. Some balances are *supposed* to change,
/// so the check is per expense rather than on a total, where a real error and a deliberate
/// correction would cancel each other out and look fine:
///
/// - An expense that recorded who paid must migrate to the cent. Drift there is a bug in the
///   migration, is named with the document it came from, and blocks the commit.
/// - An expense that recorded no payer is where the old app guessed, and guessed wrong for
///   `.currentUserOwes` — it credited nobody, so the money vanished from both sides. Naming a
///   payer moves those balances on purpose. The size of that correction is reported per
///   person, so it can be eyeballed before anything is written.
///
/// A cent of difference on a single expense is tolerated: the old splits were Doubles and did
/// not always add up to their own total, and rescaling them to whole cents is the fix, not a
/// fault. Anything larger is a real disagreement.
struct MigrationReport {
    let plan: MigrationPlan
    let comparisons: [MemberComparison]
    /// Recorded-payer expenses whose migrated numbers do not match what the app displayed.
    let drifts: [EntryDrift]

    struct MemberComparison: Hashable {
        let memberId: String
        /// What the sidebar showed.
        let sidebar: Money
        /// What the expense rows added up to.
        let rows: Money
        /// What the ledger says now.
        let ledger: Money

        /// How much this migration moves the person's balance, all causes together.
        var netChange: Money { ledger - rows }

        /// The two legacy calculations disagreeing with each other — the defect that
        /// motivated the rewrite. Reported because it is informative, not because it is fatal.
        var legacySourcesDisagree: Bool { sidebar != rows }
    }

    /// One person's share of one expense, before and after.
    struct EntryDrift: Hashable {
        let expenseId: String
        let memberId: String
        let legacy: Money
        let migrated: Money

        var delta: Money { migrated - legacy }
    }

    /// Every entry accounts for its own amount on both sides.
    var allEntriesBalance: Bool { plan.entries.allSatisfy(\.isBalanced) }

    /// Money is conserved: for every person owed, somebody owes.
    var balancesSumToZero: Bool {
        Balance.all(for: plan.members, in: plan.entries).values.total.isZero
    }

    var correctedMembers: [MemberComparison] { comparisons.filter { !$0.netChange.isZero } }

    /// Safe to commit: nothing unexplained, nothing unbalanced, no money invented or lost.
    var isClean: Bool {
        plan.blockingIssues.isEmpty && allEntriesBalance && balancesSumToZero && drifts.isEmpty
    }

    static func dryRun(plan: MigrationPlan) -> MigrationReport {
        let comparisons = plan.members.sorted().map { member in
            MemberComparison(
                memberId: member,
                sidebar: Money(roundingDollars: LegacyBalance.sidebarStyle(for: member, in: plan.legacyExpenses)),
                rows: Money(roundingDollars: LegacyBalance.rowStyle(for: member, in: plan.legacyExpenses)),
                ledger: Balance.net(for: member, in: plan.entries)
            )
        }
        return MigrationReport(plan: plan, comparisons: comparisons, drifts: drifts(in: plan))
    }

    /// Compares each recorded-payer expense against the entry it became.
    ///
    /// Settled expenses are skipped: the app stopped counting them, and on the ledger side
    /// they only cancel out once their settlement entry is counted too, so there is nothing
    /// to compare one document at a time.
    private static func drifts(in plan: MigrationPlan) -> [EntryDrift] {
        let entries = Dictionary(plan.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return plan.legacyExpenses
            .filter { !$0.payments.isEmpty && !$0.settled }
            .flatMap { expense -> [EntryDrift] in
                guard let entry = entries[expense.id] else { return [] }
                return plan.members.sorted().compactMap { member in
                    let legacy = Money(roundingDollars:
                        LegacyBalance.rowStyle(for: member, in: [expense]))
                    let drift = EntryDrift(
                        expenseId: expense.id,
                        memberId: member,
                        legacy: legacy,
                        migrated: entry.delta(for: member)
                    )
                    return abs(drift.delta.cents) > 1 ? drift : nil
                }
            }
    }

    /// Plain text, for reading in a console before deciding to commit.
    var summary: String {
        var lines: [String] = []
        lines.append("Ledger \(plan.ledgerId) — \(plan.members.count) members")
        lines.append("Read \(plan.legacyExpenses.count) expenses "
            + "→ \(plan.expenseEntries.count) entries + \(plan.settlementEntries.count) settlements")

        // Which ledger is the live one is not obvious from a count, and with two ledgers
        // between the same two people it is the question that decides what to migrate.
        if let first = plan.entries.map(\.date).min(), let last = plan.entries.map(\.date).max() {
            let format = Date.FormatStyle(date: .abbreviated, time: .omitted)
            lines.append("Activity: \(first.formatted(format)) to \(last.formatted(format))")
        }
        lines.append("")

        lines.append("Balances (sidebar / rows / ledger)")
        for comparison in comparisons {
            let flags = [
                comparison.netChange.isZero ? nil : "moves by \(comparison.netChange.formatted())",
                comparison.legacySourcesDisagree ? "legacy sources disagreed" : nil
            ].compactMap { $0 }
            let suffix = flags.isEmpty ? "unchanged" : flags.joined(separator: ", ")
            lines.append("  \(comparison.memberId): \(comparison.sidebar.formatted())"
                + " / \(comparison.rows.formatted()) / \(comparison.ledger.formatted()) — \(suffix)")
        }
        lines.append("")

        lines.append("Invariants")
        lines.append("  every entry balances: \(allEntriesBalance ? "yes" : "NO")")
        lines.append("  balances sum to zero: \(balancesSumToZero ? "yes" : "NO")")
        lines.append("  recorded payers migrate exactly: \(drifts.isEmpty ? "yes" : "NO")")
        for drift in drifts {
            lines.append("    ! \(drift.expenseId) / \(drift.memberId): "
                + "\(drift.legacy.formatted()) → \(drift.migrated.formatted())")
        }
        lines.append("")

        if plan.issues.isEmpty {
            lines.append("No issues.")
        } else {
            let blocking = plan.issues.filter(\.isBlocking)
            let notes = plan.issues.filter { !$0.isBlocking }
            lines.append("Issues: \(blocking.count) blocking, \(notes.count) informational")
            for issue in blocking { lines.append("  ! \(issue.description)") }
            for issue in notes { lines.append("  - \(issue.description)") }
        }
        lines.append("")
        lines.append(isClean ? "CLEAN — safe to commit." : "NOT CLEAN — do not commit.")

        return lines.joined(separator: "\n")
    }
}
