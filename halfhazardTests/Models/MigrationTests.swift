//
//  MigrationTests.swift
//  halfhazardTests
//

import XCTest
import FirebaseFirestore
@testable import halfhazard

private let josiah = "josiah"
private let laura = "laura"
private let pair = [josiah, laura]
private let book = "group-1"

/// Legacy expense builder. Defaults describe the ordinary case — creator paid, split evenly —
/// so each test only states the one thing it is about.
private func legacy(
    id: String = "e1",
    amount: Double,
    splitType: SplitType = .equal,
    splits: [String: Double]? = nil,
    payments: [String: Double]? = nil,
    createdBy: String = josiah,
    createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
    settled: Bool = false,
    settledAt: Date? = nil,
    description: String? = "groceries"
) -> Expense {
    Expense(
        id: id,
        amount: amount,
        description: description,
        groupId: book,
        createdBy: createdBy,
        createdAt: Timestamp(date: createdAt),
        splitType: splitType,
        splits: splits ?? [josiah: amount / 2, laura: amount / 2],
        customSplitPercentages: nil,
        payments: payments ?? [createdBy: amount],
        settled: settled,
        settledAt: settledAt.map { Timestamp(date: $0) }
    )
}

private func plan(_ expenses: [Expense], members: [String] = pair) -> MigrationPlan {
    LedgerMigrator.plan(expenses: expenses, ledgerId: book, members: members)
}

final class LedgerMigratorTests: XCTestCase {

    func testConvertsAnOrdinaryExpense() throws {
        let result = plan([legacy(amount: 84.20)])
        let entry = try XCTUnwrap(result.entries.first)

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(entry.id, "e1", "the legacy id carries over so migration is idempotent")
        XCTAssertEqual(entry.ledgerId, book)
        XCTAssertEqual(entry.kind, .expense)
        XCTAssertEqual(entry.amount, Money(cents: 8420))
        XCTAssertEqual(entry.paidBy, [josiah: Money(cents: 8420)])
        XCTAssertEqual(entry.owedBy, [josiah: Money(cents: 4210), laura: Money(cents: 4210)])
        XCTAssertEqual(entry.splitRule, .equal)
        XCTAssertEqual(entry.note, "groceries")
        XCTAssertTrue(entry.isBalanced)
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testDateComesFromTheLegacyCreatedAt() throws {
        let when = Date(timeIntervalSince1970: 1_690_000_000)
        let entry = try XCTUnwrap(plan([legacy(amount: 10, createdAt: when)]).entries.first)

        XCTAssertEqual(entry.date, when)
        XCTAssertEqual(entry.createdAt, when)
    }

    // MARK: - Resolving who paid

    func testPaymentsMapWins() throws {
        // Laura paid, even though Josiah typed it in.
        let expense = legacy(amount: 50, payments: [laura: 50], createdBy: josiah)
        let entry = try XCTUnwrap(plan([expense]).entries.first)

        XCTAssertEqual(entry.paidBy, [laura: Money(cents: 5000)])
    }

    func testMissingPaymentsFallsBackToTheCreator() throws {
        let expense = legacy(amount: 50, splitType: .equal, payments: [:])
        let result = plan([expense])
        let entry = try XCTUnwrap(result.entries.first)

        XCTAssertEqual(entry.paidBy, [josiah: Money(cents: 5000)])
        XCTAssertEqual(result.issues.map(\.kind), [.assumedPayer(josiah, from: .equal)])
        XCTAssertFalse(try XCTUnwrap(result.issues.first).isBlocking, "an inferred payer is routine")
    }

    /// The defect this migration exists to close. `.currentUserOwes` means the creator owes,
    /// so the other person paid — but the old payments migration recorded no payer at all,
    /// leaving the money credited to nobody.
    func testCurrentUserOwesCreditsTheOtherPerson() throws {
        let expense = legacy(
            amount: 30,
            splitType: .currentUserOwes,
            splits: [josiah: 30],
            payments: [:],
            createdBy: josiah
        )
        let result = plan([expense])
        let entry = try XCTUnwrap(result.entries.first)

        XCTAssertEqual(entry.paidBy, [laura: Money(cents: 3000)])
        XCTAssertEqual(entry.owedBy, [josiah: Money(cents: 3000)])
        XCTAssertEqual(entry.delta(for: josiah), Money(cents: -3000))
        XCTAssertEqual(entry.delta(for: laura), Money(cents: 3000))
        XCTAssertTrue(entry.isBalanced, "the old model left this unbalanced")
    }

    func testCurrentUserOwesIsAmbiguousBeyondTwoPeople() throws {
        let expense = legacy(
            amount: 30,
            splitType: .currentUserOwes,
            splits: [josiah: 30],
            payments: [:]
        )
        let result = plan([expense], members: [josiah, laura, "sam"])

        XCTAssertTrue(result.issues.contains { $0.kind == .ambiguousPayer(members: [josiah, laura, "sam"]) })
        XCTAssertFalse(result.blockingIssues.isEmpty, "a guessed payer among three people must block")
        XCTAssertTrue(try XCTUnwrap(result.entries.first).isBalanced)
    }

    func testCurrentUserOwedCreditsTheCreator() throws {
        let expense = legacy(amount: 30, splitType: .currentUserOwed, splits: [laura: 30], payments: [:])
        let entry = try XCTUnwrap(plan([expense]).entries.first)

        XCTAssertEqual(entry.paidBy, [josiah: Money(cents: 3000)])
        XCTAssertEqual(entry.delta(for: josiah), Money(cents: 3000))
    }

    // MARK: - Amounts that never added up

    func testSplitsAreRescaledToSumToTheTotal() throws {
        // $10.01 split evenly was stored as 5.005 each, which is 10.01 only by luck of rounding.
        let expense = legacy(amount: 10.01, splits: [josiah: 5.005, laura: 5.005])
        let entry = try XCTUnwrap(plan([expense]).entries.first)

        XCTAssertEqual(entry.amount, Money(cents: 1001))
        XCTAssertEqual(entry.owedBy.values.total, Money(cents: 1001), "parts must sum to the whole")
        XCTAssertEqual(Set(entry.owedBy.values), [Money(cents: 501), Money(cents: 500)])
        XCTAssertTrue(entry.isBalanced)
    }

    func testThreeWaySplitKeepsItsLastCent() throws {
        let expense = legacy(
            amount: 10,
            splits: [josiah: 3.333333, laura: 3.333333, "sam": 3.333333],
            payments: [josiah: 10]
        )
        let entry = try XCTUnwrap(plan([expense], members: [josiah, laura, "sam"]).entries.first)

        XCTAssertEqual(entry.owedBy.values.total, Money(cents: 1000))
        XCTAssertTrue(entry.isBalanced)
    }

    func testSplitsThatAreFarFromTheTotalAreFlagged() {
        let expense = legacy(amount: 100, splits: [josiah: 25, laura: 25])
        let result = plan([expense])

        XCTAssertTrue(result.issues.contains {
            $0.kind == .splitsDidNotSumToAmount(recorded: Money(cents: 5000), expected: Money(cents: 10000))
        })
        XCTAssertFalse(result.blockingIssues.isEmpty)
        XCTAssertTrue(
            try! XCTUnwrap(result.entries.first).isBalanced,
            "flagged or not, the entry still has to balance"
        )
    }

    func testMissingSplitsFallBackToAnEqualDivision() throws {
        let expense = legacy(amount: 40, splits: [:])
        let result = plan([expense])
        let entry = try XCTUnwrap(result.entries.first)

        XCTAssertEqual(entry.owedBy, [josiah: Money(cents: 2000), laura: Money(cents: 2000)])
        XCTAssertTrue(result.issues.contains { $0.kind == .splitsMissing })
        XCTAssertTrue(result.blockingIssues.isEmpty, "an even division of a two-person expense is safe")
    }

    func testSomebodyOutsideTheGroupBlocks() {
        let expense = legacy(amount: 60, splits: [josiah: 30, "stranger": 30])
        let result = plan([expense])

        XCTAssertTrue(result.issues.contains { $0.kind == .unknownParticipant("stranger") })
        XCTAssertFalse(result.blockingIssues.isEmpty)
    }

    // MARK: - Split rules

    func testUnevenSplitsBecomeExactAmounts() throws {
        // A 70/30 custom split. The percentages are not recovered: they were applied to
        // members by array index in the old code, so only the dollars can be trusted.
        let expense = legacy(amount: 100, splitType: .custom, splits: [josiah: 70, laura: 30])
        let entry = try XCTUnwrap(plan([expense]).entries.first)

        XCTAssertEqual(entry.splitRule, .exact([josiah: Money(cents: 7000), laura: Money(cents: 3000)]))
    }

    func testEvenSplitsBecomeTheEqualRuleEvenWithAnOddCent() throws {
        let entry = try XCTUnwrap(plan([legacy(amount: 10.01)]).entries.first)

        XCTAssertEqual(entry.splitRule, .equal, "one leftover cent is what an equal split looks like")
    }

    // MARK: - Settlements

    func testASettledExpenseGetsASettlementThatCancelsIt() throws {
        let settledAt = Date(timeIntervalSince1970: 1_700_100_000)
        let expense = legacy(amount: 84.20, settled: true, settledAt: settledAt)
        let result = plan([expense])

        XCTAssertEqual(result.expenseEntries.count, 1)
        let settlement = try XCTUnwrap(result.settlementEntries.first)
        XCTAssertEqual(settlement.kind, .settlement)
        XCTAssertEqual(settlement.amount, Money(cents: 4210))
        XCTAssertEqual(settlement.paidBy, [laura: Money(cents: 4210)], "Laura owed her half, so Laura pays")
        XCTAssertEqual(settlement.owedBy, [josiah: Money(cents: 4210)])
        XCTAssertEqual(settlement.date, settledAt)
        XCTAssertNil(settlement.splitRule)

        XCTAssertEqual(Balance.net(for: josiah, in: result.entries), .zero)
        XCTAssertEqual(Balance.net(for: laura, in: result.entries), .zero)
    }

    func testTheSpentAmountSurvivesSettlement() throws {
        let expense = legacy(amount: 84.20, settled: true, settledAt: Date(timeIntervalSince1970: 1_700_100_000))
        let entry = try XCTUnwrap(plan([expense]).expenseEntries.first)

        XCTAssertEqual(entry.amount, Money(cents: 8420), "history keeps its real numbers")
    }

    func testOneSettlementPerBatch() throws {
        let first = Date(timeIntervalSince1970: 1_700_100_000)
        let second = Date(timeIntervalSince1970: 1_700_200_000)
        let result = plan([
            legacy(id: "a", amount: 20, settled: true, settledAt: first),
            legacy(id: "b", amount: 30, settled: true, settledAt: first),
            legacy(id: "c", amount: 50, settled: true, settledAt: second)
        ])

        XCTAssertEqual(result.settlementEntries.count, 2)
        let batched = try XCTUnwrap(result.settlementEntries.first { $0.date == first })
        XCTAssertEqual(batched.amount, Money(cents: 2500), "half of $50 spent, in one transfer")
        XCTAssertEqual(Balance.net(for: laura, in: result.entries), .zero)
    }

    func testASettlementBatchNetsAcrossBothDirections() throws {
        // Josiah paid for one, Laura paid for the other, then they squared up.
        let settledAt = Date(timeIntervalSince1970: 1_700_100_000)
        let result = plan([
            legacy(id: "a", amount: 100, createdBy: josiah, settled: true, settledAt: settledAt),
            legacy(id: "b", amount: 40, createdBy: laura, settled: true, settledAt: settledAt)
        ])

        let settlement = try XCTUnwrap(result.settlementEntries.first)
        XCTAssertEqual(result.settlementEntries.count, 1)
        XCTAssertEqual(settlement.amount, Money(cents: 3000), "$50 owed less $20 owed back")
        XCTAssertEqual(settlement.paidBy, [laura: Money(cents: 3000)])
        XCTAssertEqual(Balance.net(for: josiah, in: result.entries), .zero)
    }

    func testAnAlreadyEvenBatchNeedsNoSettlement() {
        let settledAt = Date(timeIntervalSince1970: 1_700_100_000)
        let result = plan([
            legacy(id: "a", amount: 40, createdBy: josiah, settled: true, settledAt: settledAt),
            legacy(id: "b", amount: 40, createdBy: laura, settled: true, settledAt: settledAt)
        ])

        XCTAssertTrue(result.settlementEntries.isEmpty, "nothing was owed, so nothing was handed over")
        XCTAssertEqual(Balance.net(for: josiah, in: result.entries), .zero)
    }

    func testSettledWithoutATimestampStillCancelsOut() {
        let result = plan([legacy(amount: 40, settled: true, settledAt: nil)])

        XCTAssertEqual(result.settlementEntries.count, 1)
        XCTAssertTrue(result.issues.contains { $0.kind == .settledWithoutTimestamp })
        XCTAssertEqual(Balance.net(for: laura, in: result.entries), .zero)
    }

    func testUnsettledExpensesAreLeftOutstanding() {
        let result = plan([legacy(amount: 40, settled: false)])

        XCTAssertTrue(result.settlementEntries.isEmpty)
        XCTAssertEqual(Balance.net(for: josiah, in: result.entries), Money(cents: 2000))
    }

    // MARK: - Whole-plan properties

    func testRunningTwiceProducesTheSameDocuments() {
        let expenses = [
            legacy(id: "a", amount: 84.20),
            legacy(id: "b", amount: 12.34, createdBy: laura),
            legacy(id: "c", amount: 40, settled: true, settledAt: Date(timeIntervalSince1970: 1_700_100_000))
        ]

        XCTAssertEqual(plan(expenses).entries, plan(expenses.reversed()).entries,
                       "ids and ordering must not depend on the order rows came back")
    }

    func testBalancesAlwaysSumToZero() {
        let result = plan([
            legacy(id: "a", amount: 84.20),
            legacy(id: "b", amount: 10.01, createdBy: laura),
            legacy(id: "c", amount: 30, splitType: .currentUserOwes, splits: [josiah: 30], payments: [:]),
            legacy(id: "d", amount: 55.55, settled: true, settledAt: Date(timeIntervalSince1970: 1_700_100_000)),
            legacy(id: "e", amount: 100, splitType: .custom, splits: [josiah: 70, laura: 30])
        ])

        XCTAssertTrue(result.entries.allSatisfy(\.isBalanced))
        XCTAssertEqual(Balance.all(for: pair, in: result.entries).values.total, .zero)
    }

    func testTheLedgerCarriesTheGroupMembership() {
        let ledger = plan([legacy(amount: 10)]).ledger

        XCTAssertEqual(ledger.id, book)
        XCTAssertEqual(ledger.memberIds, pair)
        XCTAssertEqual(ledger.partner(of: josiah), laura)
    }
}

final class MigrationReportTests: XCTestCase {

    func testCleanRunOnWellFormedData() {
        let report = MigrationReport.dryRun(plan: plan([
            legacy(id: "a", amount: 84.20),
            legacy(id: "b", amount: 12.34, createdBy: laura),
            legacy(id: "c", amount: 40, settled: true, settledAt: Date(timeIntervalSince1970: 1_700_100_000))
        ]))

        XCTAssertTrue(report.isClean)
        XCTAssertTrue(report.drifts.isEmpty)
        XCTAssertTrue(report.allEntriesBalance)
        XCTAssertTrue(report.balancesSumToZero)
        XCTAssertTrue(report.correctedMembers.isEmpty, "nothing was inferred, so nothing should move")
    }

    func testBalancesCarryOverUnchangedWhenThePayerWasRecorded() throws {
        let report = MigrationReport.dryRun(plan: plan([
            legacy(id: "a", amount: 84.20, createdBy: josiah),
            legacy(id: "b", amount: 30, createdBy: laura)
        ]))
        let josiahs = try XCTUnwrap(report.comparisons.first { $0.memberId == josiah })

        XCTAssertEqual(josiahs.rows, Money(cents: 2710))
        XCTAssertEqual(josiahs.ledger, josiahs.rows)
        XCTAssertTrue(josiahs.netChange.isZero)
    }

    func testSettledExpensesLeaveTheBalanceWhereTheLegacyAppLeftIt() throws {
        let report = MigrationReport.dryRun(plan: plan([
            legacy(id: "a", amount: 84.20, settled: true, settledAt: Date(timeIntervalSince1970: 1_700_100_000)),
            legacy(id: "b", amount: 20)
        ]))
        let josiahs = try XCTUnwrap(report.comparisons.first { $0.memberId == josiah })

        XCTAssertEqual(josiahs.rows, Money(cents: 1000), "the old app counted only the unsettled one")
        XCTAssertEqual(josiahs.ledger, Money(cents: 1000), "so must the ledger, settlements included")
        XCTAssertTrue(report.isClean)
    }

    /// The correction is reported rather than hidden: naming a payer on a `.currentUserOwes`
    /// expense moves both balances, and the report says by how much without calling it a fault.
    func testInferredPayersShowUpAsAReportedCorrection() throws {
        let report = MigrationReport.dryRun(plan: plan([
            legacy(id: "a", amount: 30, splitType: .currentUserOwes, splits: [josiah: 30], payments: [:])
        ]))
        let lauras = try XCTUnwrap(report.comparisons.first { $0.memberId == laura })

        XCTAssertEqual(lauras.rows, .zero, "the old app credited her nothing for money she fronted")
        XCTAssertEqual(lauras.ledger, Money(cents: 3000))
        XCTAssertEqual(lauras.netChange, Money(cents: 3000))
        XCTAssertTrue(report.drifts.isEmpty, "a correction is not a drift")
        XCTAssertTrue(report.isClean)
    }

    func testTheTwoLegacyCalculationsDisagreeingIsVisible() throws {
        // Laura paid but Josiah typed it in: the sidebar credited Josiah, the rows credited Laura.
        let report = MigrationReport.dryRun(plan: plan([
            legacy(id: "a", amount: 50, payments: [laura: 50], createdBy: josiah)
        ]))
        let josiahs = try XCTUnwrap(report.comparisons.first { $0.memberId == josiah })

        XCTAssertTrue(josiahs.legacySourcesDisagree)
        XCTAssertEqual(josiahs.sidebar, Money(cents: 2500))
        XCTAssertEqual(josiahs.rows, Money(cents: -2500))
        XCTAssertEqual(josiahs.ledger, josiahs.rows, "the payments-aware figure is the true one")
        XCTAssertTrue(report.isClean, "the legacy sources disagreeing is a report, not a blocker")
    }

    func testBlockingIssuesStopTheRun() {
        let report = MigrationReport.dryRun(plan: plan([
            legacy(id: "a", amount: 100, splits: [josiah: 25, laura: 25])
        ]))

        XCTAssertFalse(report.isClean)
        XCTAssertFalse(report.plan.blockingIssues.isEmpty)
        XCTAssertTrue(report.summary.contains("NOT CLEAN"))
    }

    /// A migration that moves money on an expense whose payer was recorded is a bug, and the
    /// report has to name the document rather than let it net out against something else.
    func testDriftIsCaughtPerDocument() {
        let honest = legacy(id: "a", amount: 50, payments: [josiah: 50])
        var tampered = plan([honest])
        let broken = LedgerEntry(
            id: "a",
            ledgerId: book,
            kind: .expense,
            amount: Money(cents: 5000),
            paidBy: [laura: Money(cents: 5000)],
            owedBy: [josiah: Money(cents: 2500), laura: Money(cents: 2500)],
            note: nil,
            category: nil,
            splitRule: .equal,
            date: honest.createdAt.dateValue(),
            createdAt: honest.createdAt.dateValue(),
            createdBy: josiah
        )
        tampered = MigrationPlan(
            ledgerId: tampered.ledgerId,
            members: tampered.members,
            entries: [broken],
            issues: [],
            legacyExpenses: tampered.legacyExpenses
        )

        let report = MigrationReport.dryRun(plan: tampered)

        XCTAssertEqual(report.drifts.count, 2, "both members' shares moved")
        XCTAssertEqual(report.drifts.first?.expenseId, "a")
        XCTAssertFalse(report.isClean)
        XCTAssertTrue(report.summary.contains("recorded payers migrate exactly: NO"))
    }

    func testSummaryCountsWhatItWouldWrite() {
        let report = MigrationReport.dryRun(plan: plan([
            legacy(id: "a", amount: 20),
            legacy(id: "b", amount: 40, settled: true, settledAt: Date(timeIntervalSince1970: 1_700_100_000))
        ]))

        XCTAssertTrue(report.summary.contains("Read 2 expenses"))
        XCTAssertTrue(report.summary.contains("2 entries + 1 settlements"))
        XCTAssertTrue(report.summary.contains("CLEAN"))
    }
}
