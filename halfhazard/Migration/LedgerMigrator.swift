//
//  LedgerMigrator.swift
//  halfhazard
//

import Foundation
import FirebaseFirestore

/// Turns the old `expenses` collection into ledger entries.
///
/// Pure by design: it takes already-decoded legacy documents and returns a plan. Nothing
/// here touches Firestore, so the whole conversion — including every assumption it has to
/// make about legacy data — is testable without a network.
///
/// The legacy model recorded intent viewer-relatively (`SplitType.currentUserOwes` means
/// "whoever created this owes"), and re-derived it on every render. Migration resolves that
/// intent **once** and writes the result down explicitly as `paidBy` / `owedBy`.
enum LedgerMigrator {

    /// Converts a group's expenses into the entries that replace them.
    ///
    /// - Parameters:
    ///   - expenses: every legacy expense in the group, settled and unsettled.
    ///   - ledgerId: the id of the `Ledger` the entries belong to (the old group id).
    ///   - members: the group's member ids, used to resolve legacy payer intent and to fill
    ///     in missing splits.
    static func plan(
        expenses: [Expense],
        ledgerId: String,
        members: [String]
    ) -> MigrationPlan {
        let ordered = expenses.sorted {
            $0.createdAt.dateValue() == $1.createdAt.dateValue()
                ? $0.id < $1.id
                : $0.createdAt.dateValue() < $1.createdAt.dateValue()
        }

        var converted: [(expense: Expense, entry: LedgerEntry)] = []
        var issues: [MigrationIssue] = []

        for expense in ordered {
            let result = convert(expense, ledgerId: ledgerId, members: members)
            converted.append((expense, result.entry))
            issues.append(contentsOf: result.issues)
        }

        let settlements = synthesizeSettlements(from: converted, ledgerId: ledgerId)

        var entries = converted.map(\.entry)
        entries.append(contentsOf: settlements.entries)
        issues.append(contentsOf: settlements.issues)

        // Should be unreachable: every path above balances its maps against `amount`.
        // Checked anyway because an unbalanced entry corrupts balances silently.
        for entry in entries where !entry.isBalanced {
            issues.append(MigrationIssue(expenseId: entry.id, kind: .unbalancedEntry))
        }

        return MigrationPlan(
            ledgerId: ledgerId,
            members: members,
            entries: entries,
            issues: issues,
            legacyExpenses: ordered
        )
    }

    // MARK: - One expense

    private static func convert(
        _ expense: Expense,
        ledgerId: String,
        members: [String]
    ) -> (entry: LedgerEntry, issues: [MigrationIssue]) {
        var issues: [MigrationIssue] = []
        let amount = Money(roundingDollars: expense.amount)

        if amount.cents < 0 {
            issues.append(MigrationIssue(expenseId: expense.id, kind: .negativeAmount(amount)))
        }

        let paidBy = resolvePaidBy(expense, amount: amount, members: members, issues: &issues)
        let owedBy = resolveOwedBy(expense, amount: amount, members: members, issues: &issues)

        let known = Set(members)
        for stray in Set(paidBy.keys).union(owedBy.keys).subtracting(known).sorted() {
            issues.append(MigrationIssue(expenseId: expense.id, kind: .unknownParticipant(stray)))
        }

        let entry = LedgerEntry(
            // Keeping the legacy document id makes the migration idempotent and lets a
            // migrated row still be traced back to what it came from.
            id: expense.id,
            ledgerId: ledgerId,
            kind: .expense,
            amount: amount,
            paidBy: paidBy,
            owedBy: owedBy,
            note: expense.description,
            category: nil,
            splitRule: inferRule(owedBy: owedBy, amount: amount),
            date: expense.createdAt.dateValue(),
            createdAt: expense.createdAt.dateValue(),
            createdBy: expense.createdBy
        )
        return (entry, issues)
    }

    /// Who actually put money in.
    ///
    /// `payments` is authoritative when present. When it is empty the legacy intent lives in
    /// `splitType`, and this is the only place that guess is ever made — the answer is then
    /// stored on the entry rather than re-derived per render.
    private static func resolvePaidBy(
        _ expense: Expense,
        amount: Money,
        members: [String],
        issues: inout [MigrationIssue]
    ) -> [String: Money] {
        if !expense.payments.isEmpty {
            let rescaled = SplitAllocator.rescale(expense.payments, to: amount)
            let raw = Money(roundingDollars: expense.payments.values.reduce(0, +))
            let drift = raw - amount
            if abs(drift.cents) > expense.payments.count {
                issues.append(MigrationIssue(
                    expenseId: expense.id,
                    kind: .paymentsDidNotSumToAmount(recorded: raw, expected: amount)
                ))
            }
            return rescaled
        }

        switch expense.splitType {
        case .currentUserOwed, .equal, .custom:
            issues.append(MigrationIssue(
                expenseId: expense.id,
                kind: .assumedPayer(expense.createdBy, from: expense.splitType)
            ))
            return [expense.createdBy: amount]

        case .currentUserOwes:
            // The creator owes, so the *other* person fronted the money. The old payments
            // migration (`ExpenseService.migrateExpensePayments`) recorded no payment at all
            // here, which left these expenses unbalanced. With two people it is unambiguous.
            let others = members.filter { $0 != expense.createdBy }
            guard others.count == 1, let payer = others.first else {
                issues.append(MigrationIssue(expenseId: expense.id, kind: .ambiguousPayer(members: members)))
                return [expense.createdBy: amount]
            }
            issues.append(MigrationIssue(
                expenseId: expense.id,
                kind: .assumedPayer(payer, from: .currentUserOwes)
            ))
            return [payer: amount]
        }
    }

    /// Who the money was for, rescaled so the parts sum to the total exactly.
    private static func resolveOwedBy(
        _ expense: Expense,
        amount: Money,
        members: [String],
        issues: inout [MigrationIssue]
    ) -> [String: Money] {
        guard !expense.splits.isEmpty else {
            issues.append(MigrationIssue(expenseId: expense.id, kind: .splitsMissing))
            return (try? SplitAllocator.allocate(total: amount, rule: .equal, among: members)) ?? [:]
        }

        let raw = Money(roundingDollars: expense.splits.values.reduce(0, +))
        let drift = raw - amount
        if abs(drift.cents) > expense.splits.count {
            issues.append(MigrationIssue(
                expenseId: expense.id,
                kind: .splitsDidNotSumToAmount(recorded: raw, expected: amount)
            ))
        }
        return SplitAllocator.rescale(expense.splits, to: amount)
    }

    /// Recovers intent from the amounts, and only the intent the amounts can prove.
    ///
    /// Old percentages are deliberately not recovered: `customSplitPercentages` was applied
    /// to members by array index in places, so the stored percentages cannot be trusted to
    /// belong to the people they sit next to. The dollar figures are what actually happened.
    private static func inferRule(owedBy: [String: Money], amount: Money) -> SplitRule {
        let participants = owedBy.keys.sorted()
        let even = try? SplitAllocator.allocate(total: amount, rule: .equal, among: participants)
        return even == owedBy ? .equal : .exact(owedBy)
    }

    // MARK: - Settlements

    /// Rebuilds settlement history from the `settled` flag.
    ///
    /// A settled expense keeps its real numbers — deleting them would erase what was spent —
    /// and each settlement batch becomes one entry that cancels exactly what that batch left
    /// outstanding. History and current balance both survive.
    ///
    /// Batches are keyed on the exact `settledAt` value: `GroupService.settleGroup` stamps
    /// one timestamp across the whole batch, while settling a single expense stamps its own.
    private static func synthesizeSettlements(
        from converted: [(expense: Expense, entry: LedgerEntry)],
        ledgerId: String
    ) -> (entries: [LedgerEntry], issues: [MigrationIssue]) {
        var batches: [Timestamp: [(expense: Expense, entry: LedgerEntry)]] = [:]
        var issues: [MigrationIssue] = []

        for pair in converted where pair.expense.settled {
            guard let settledAt = pair.expense.settledAt else {
                // Settled with no timestamp: the balance effect has to be undone, but there
                // is no batch to join, so it settles alone at its own creation time.
                issues.append(MigrationIssue(expenseId: pair.expense.id, kind: .settledWithoutTimestamp))
                batches[pair.expense.createdAt, default: []].append(pair)
                continue
            }
            batches[settledAt, default: []].append(pair)
        }

        var entries: [LedgerEntry] = []
        for settledAt in batches.keys.sorted(by: { $0.dateValue() < $1.dateValue() }) {
            guard let batch = batches[settledAt] else { continue }
            let members = batch.flatMap { Array($0.entry.participants) }
            let net = Set(members).reduce(into: [String: Money]()) { result, member in
                result[member] = batch.reduce(Money.zero) { $0 + $1.entry.delta(for: member) }
            }

            // Whoever came out ahead is owed; whoever came out behind hands the money over.
            // Written generically so a three-way batch still produces one balanced entry,
            // though in practice there are two people and it reduces to a simple transfer.
            let creditors = net.filter { $0.value.cents > 0 }
            let debtors = net.filter { $0.value.cents < 0 }
            guard !creditors.isEmpty, !debtors.isEmpty else { continue }

            let total = creditors.values.total
            let payer = debtors.min { $0.key < $1.key }?.key ?? ""
            entries.append(LedgerEntry(
                // Derived from the batch's first expense so re-running the migration
                // overwrites the same document instead of adding a second settlement.
                id: settlementId(for: batch),
                ledgerId: ledgerId,
                kind: .settlement,
                amount: total,
                paidBy: debtors.mapValues { $0.magnitude },
                owedBy: creditors,
                note: "Settled up",
                category: nil,
                splitRule: nil,
                date: settledAt.dateValue(),
                createdAt: settledAt.dateValue(),
                // Nobody recorded who pressed settle; the payer is the closest true answer.
                createdBy: payer
            ))
        }

        return (entries, issues)
    }

    private static func settlementId(for batch: [(expense: Expense, entry: LedgerEntry)]) -> String {
        let anchor = batch.map(\.expense.id).sorted().first ?? UUID().uuidString
        return "settlement-\(anchor)"
    }
}

// MARK: - Plan

/// Everything the migration would write, plus everything it had to assume to get there.
struct MigrationPlan {
    let ledgerId: String
    let members: [String]
    let entries: [LedgerEntry]
    let issues: [MigrationIssue]
    /// The source documents, kept so the dry run can recompute balances the old way.
    let legacyExpenses: [Expense]

    var expenseEntries: [LedgerEntry] { entries.filter { $0.kind == .expense } }
    var settlementEntries: [LedgerEntry] { entries.filter { $0.kind == .settlement } }
    var blockingIssues: [MigrationIssue] { issues.filter(\.isBlocking) }

    var ledger: Ledger {
        Ledger(
            id: ledgerId,
            memberIds: members,
            createdAt: entries.map(\.createdAt).min() ?? Date()
        )
    }
}

/// Something the migration could not read straight off the old document.
///
/// Assumptions are reported rather than hidden: a legacy expense with no `payments` map has
/// no recorded payer, and the reader deserves to see which ones were inferred.
struct MigrationIssue: Hashable {
    enum Kind: Hashable {
        /// No `payments` map; the payer was inferred from the legacy split type.
        case assumedPayer(String, from: SplitType)
        /// `.currentUserOwes` in a group that is not exactly two people, so "the other
        /// person" has no single answer.
        case ambiguousPayer(members: [String])
        case paymentsDidNotSumToAmount(recorded: Money, expected: Money)
        case splitsMissing
        case splitsDidNotSumToAmount(recorded: Money, expected: Money)
        case unknownParticipant(String)
        case negativeAmount(Money)
        case settledWithoutTimestamp
        case unbalancedEntry
    }

    let expenseId: String
    let kind: Kind

    /// Whether this should stop a commit. Inferred payers are expected and routine;
    /// figures that do not add up, or people who should not be here, are not.
    var isBlocking: Bool {
        switch kind {
        case .assumedPayer, .splitsMissing:
            return false
        case .ambiguousPayer, .paymentsDidNotSumToAmount, .splitsDidNotSumToAmount,
             .unknownParticipant, .negativeAmount, .settledWithoutTimestamp, .unbalancedEntry:
            return true
        }
    }

    var message: String {
        switch kind {
        case .assumedPayer(let payer, let type):
            return "no payments recorded; inferred \(payer) paid, from splitType .\(type.rawValue)"
        case .ambiguousPayer(let members):
            return "splitType .currentUserOwes but the group has \(members.count) members, so the payer is a guess"
        case .paymentsDidNotSumToAmount(let recorded, let expected):
            return "payments add up to \(recorded.formatted()), not \(expected.formatted())"
        case .splitsMissing:
            return "no splits recorded; divided equally among members"
        case .splitsDidNotSumToAmount(let recorded, let expected):
            return "splits add up to \(recorded.formatted()), not \(expected.formatted())"
        case .unknownParticipant(let id):
            return "refers to \(id), who is not a member of the group"
        case .negativeAmount(let amount):
            return "amount is negative (\(amount.formatted()))"
        case .settledWithoutTimestamp:
            return "settled but has no settledAt; settled on its own at its creation date"
        case .unbalancedEntry:
            return "migrated entry does not balance — this is a bug, do not commit"
        }
    }

    var description: String { "\(expenseId): \(message)" }
}
