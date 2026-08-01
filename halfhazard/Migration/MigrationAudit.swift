//
//  MigrationAudit.swift
//  halfhazard
//

import Foundation

/// What is actually in the database, checked against what should be.
///
/// The dry run is a prediction; this is the receipt. It exists because the two failure modes
/// that matter most are invisible from the commit side: a batch that failed after another
/// one succeeded, and a run that wrote nothing at all — which from the outside looks exactly
/// like a run that worked.
struct MigrationAudit {
    /// What the migration says should be there, recomputed from the legacy documents.
    let plan: MigrationPlan
    /// What came back from the `entries` collection.
    let written: [LedgerEntry]
    let ledgerDocumentExists: Bool

    private var expectedById: [String: LedgerEntry] {
        Dictionary(plan.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var writtenById: [String: LedgerEntry] {
        Dictionary(written.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Entries the migration should have written that are not there.
    var missing: [String] {
        expectedById.keys.filter { writtenById[$0] == nil }.sorted()
    }

    /// Entries in the collection that this migration did not put there. Not necessarily
    /// wrong — anything the app writes after the cutover lands here too — but on the day of
    /// the migration it means something is out of step.
    var unexpected: [String] {
        writtenById.keys.filter { expectedById[$0] == nil }.sorted()
    }

    /// Same id, different numbers. Money is compared rather than the whole record, because
    /// a differing note is a nuisance and a differing amount is a problem.
    var altered: [String] {
        expectedById.keys.filter { id in
            guard let written = writtenById[id], let expected = expectedById[id] else { return false }
            return written.amount != expected.amount
                || written.paidBy != expected.paidBy
                || written.owedBy != expected.owedBy
        }.sorted()
    }

    /// What each person's balance reads as in the database, next to what it should read as.
    var balances: [(member: String, expected: Money, actual: Money)] {
        plan.members.sorted().map { member in
            (member,
             Balance.net(for: member, in: plan.entries),
             Balance.net(for: member, in: written))
        }
    }

    var balancesMatch: Bool { balances.allSatisfy { $0.expected == $0.actual } }

    /// Nothing missing, nothing altered, and the money reads the same as it should.
    /// Unexpected entries are reported but do not fail the audit.
    var isComplete: Bool {
        ledgerDocumentExists && missing.isEmpty && altered.isEmpty && balancesMatch
    }

    var summary: String {
        var lines: [String] = []
        lines.append("Ledger \(plan.ledgerId)")
        lines.append("  ledger document: \(ledgerDocumentExists ? "present" : "MISSING")")
        lines.append("  entries: \(written.count) in the database, \(plan.entries.count) expected")

        if written.isEmpty {
            lines.append("  nothing has been written yet — the commit did not run, or it was denied")
        }
        if !missing.isEmpty {
            lines.append("  missing \(missing.count): \(missing.prefix(10).joined(separator: ", "))")
        }
        if !altered.isEmpty {
            lines.append("  altered \(altered.count): \(altered.prefix(10).joined(separator: ", "))")
        }
        if !unexpected.isEmpty {
            lines.append("  \(unexpected.count) entries not from this migration (fine after cutover)")
        }

        lines.append("  balances (expected vs in database)")
        for balance in balances {
            let mark = balance.expected == balance.actual ? "ok" : "MISMATCH"
            lines.append("    \(balance.member): \(balance.expected.formatted())"
                + " vs \(balance.actual.formatted()) — \(mark)")
        }

        lines.append(isComplete ? "  MIGRATED — the ledger matches the old data." : "  INCOMPLETE.")
        return lines.joined(separator: "\n")
    }
}
