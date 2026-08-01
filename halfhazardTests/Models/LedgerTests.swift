//
//  LedgerTests.swift
//  halfhazardTests
//

import XCTest
@testable import halfhazard

private let josiah = "josiah"
private let laura = "laura"
private let pair = [josiah, laura]
private let book = "ledger-1"

final class MoneyTests: XCTestCase {
    func testArithmetic() {
        XCTAssertEqual(Money(cents: 4210) + Money(cents: 790), Money(cents: 5000))
        XCTAssertEqual(Money(cents: 4210) - Money(cents: 5000), Money(cents: -790))
        XCTAssertEqual(-Money(cents: 250), Money(cents: -250))
        XCTAssertEqual(Money(cents: -250).magnitude, Money(cents: 250))
    }

    func testRoundingFromDollarsRecoversLegacyAmounts() {
        // 0.29 * 100 is 28.9999... in binary floating point; truncating would lose a cent.
        XCTAssertEqual(Money(roundingDollars: 8.42).cents, 842)
        XCTAssertEqual(Money(roundingDollars: 0.29).cents, 29)
        XCTAssertEqual(Money(roundingDollars: 84.20).cents, 8420)
        XCTAssertEqual(Money(roundingDollars: 10.01).cents, 1001)
    }

    /// Pins the limit of the Double path so nobody "fixes" it in the wrong direction.
    /// 1.005 is not representable — it is held as 1.00499999999999989 — so no amount of
    /// rounding recovers 101c from it. The answer is to not use Double for input.
    func testDoubleInputCannotRepresentEveryHalfCent() {
        XCTAssertEqual(Money(roundingDollars: 1.005).cents, 100)
        XCTAssertEqual(Money(decimalDollars: Decimal(string: "1.005")!).cents, 101)
    }

    func testDecimalInputIsExact() {
        XCTAssertEqual(Money(decimalDollars: Decimal(string: "84.20")!).cents, 8420)
        XCTAssertEqual(Money(decimalDollars: Decimal(string: "0.29")!).cents, 29)
        XCTAssertEqual(Money(decimalDollars: Decimal(string: "0.145")!).cents, 15)
        XCTAssertEqual(Money(decimalDollars: Decimal(string: "-12.34")!).cents, -1234)
    }

    func testParsingTypedInput() {
        XCTAssertEqual(Money(parsingDollars: "84.20")?.cents, 8420)
        XCTAssertEqual(Money(parsingDollars: "$84.20")?.cents, 8420)
        XCTAssertEqual(Money(parsingDollars: " 12 ")?.cents, 1200)
        XCTAssertEqual(Money(parsingDollars: "-12.34")?.cents, -1234)
        XCTAssertEqual(Money(parsingDollars: ".5")?.cents, 50)
        XCTAssertNil(Money(parsingDollars: ""))
        XCTAssertNil(Money(parsingDollars: "abc"))
        XCTAssertNil(Money(parsingDollars: "1.2.3"))
    }

    func testEncodesAsBareInteger() throws {
        struct Wrapper: Codable { let amount: Money }

        let data = try JSONEncoder().encode(Wrapper(amount: Money(cents: 4210)))
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, #"{"amount":4210}"#)

        let decoded = try JSONDecoder().decode(Wrapper.self, from: data)
        XCTAssertEqual(decoded.amount, Money(cents: 4210))
    }

    func testTotalOfSequence() {
        XCTAssertEqual([Money(cents: 100), Money(cents: 250)].total, Money(cents: 350))
        XCTAssertEqual([Money]().total, .zero)
    }
}

final class SplitAllocatorTests: XCTestCase {

    // MARK: - The invariant that matters

    func testEqualSplitsAlwaysSumToTheTotal() throws {
        for cents in 0...1500 {
            for people in 1...5 {
                let participants = (0..<people).map { "user-\($0)" }
                let allocation = try SplitAllocator.allocate(
                    total: Money(cents: cents),
                    rule: .equal,
                    among: participants
                )
                XCTAssertEqual(
                    allocation.values.total.cents, cents,
                    "equal split of \(cents)c among \(people) lost or gained a cent"
                )
            }
        }
    }

    func testPercentageSplitsAlwaysSumToTheTotal() throws {
        let awkward: [[Double]] = [
            [50, 50], [33.33, 33.33, 33.34], [60, 40], [1, 99], [70.5, 29.5],
        ]
        for weights in awkward {
            let participants = (0..<weights.count).map { "user-\($0)" }
            let percentages = Dictionary(uniqueKeysWithValues: zip(participants, weights))
            for cents in stride(from: 1, through: 20_000, by: 7) {
                let allocation = try SplitAllocator.allocate(
                    total: Money(cents: cents),
                    rule: .percentage(percentages),
                    among: participants
                )
                XCTAssertEqual(
                    allocation.values.total.cents, cents,
                    "percentage split \(weights) of \(cents)c did not reconcile"
                )
            }
        }
    }

    func testShareSplitsAlwaysSumToTheTotal() throws {
        for cents in stride(from: 0, through: 5000, by: 3) {
            let allocation = try SplitAllocator.allocate(
                total: Money(cents: cents),
                rule: .shares([josiah: 2, laura: 1]),
                among: pair
            )
            XCTAssertEqual(allocation.values.total.cents, cents)
        }
    }

    // MARK: - Specific expectations

    func testEvenSplitOfAnOddAmount() throws {
        let allocation = try SplitAllocator.allocate(
            total: Money(cents: 901),
            rule: .equal,
            among: pair
        )
        // The odd cent goes to the alphabetically first id so the result is reproducible.
        XCTAssertEqual(allocation[josiah], Money(cents: 451))
        XCTAssertEqual(allocation[laura], Money(cents: 450))
    }

    func testThreeWaySplitOfTenDollars() throws {
        let participants = ["a", "b", "c"]
        let allocation = try SplitAllocator.allocate(
            total: Money(cents: 1000),
            rule: .equal,
            among: participants
        )
        XCTAssertEqual(allocation["a"], Money(cents: 334))
        XCTAssertEqual(allocation["b"], Money(cents: 333))
        XCTAssertEqual(allocation["c"], Money(cents: 333))
    }

    func testCleanFiftyFifty() throws {
        let allocation = try SplitAllocator.allocate(
            total: Money(cents: 8420),
            rule: .equal,
            among: pair
        )
        XCTAssertEqual(allocation[josiah], Money(cents: 4210))
        XCTAssertEqual(allocation[laura], Money(cents: 4210))
    }

    func testSharesRespectWeighting() throws {
        let allocation = try SplitAllocator.allocate(
            total: Money(cents: 3000),
            rule: .shares([josiah: 2, laura: 1]),
            among: pair
        )
        XCTAssertEqual(allocation[josiah], Money(cents: 2000))
        XCTAssertEqual(allocation[laura], Money(cents: 1000))
    }

    func testAllocationIsDeterministic() throws {
        let rule = SplitRule.percentage([josiah: 33.33, laura: 66.67])
        let first = try SplitAllocator.allocate(total: Money(cents: 999), rule: rule, among: pair)
        let second = try SplitAllocator.allocate(total: Money(cents: 999), rule: rule, among: pair)
        XCTAssertEqual(first, second)
    }

    // MARK: - Rejections

    func testPercentagesMustSumTo100() {
        XCTAssertThrowsError(
            try SplitAllocator.allocate(
                total: Money(cents: 1000),
                rule: .percentage([josiah: 40, laura: 40]),
                among: pair
            )
        ) { error in
            XCTAssertEqual(error as? SplitError, .percentagesMustSumTo100(actual: 80))
        }
    }

    func testExactAmountsMustSumToTotal() {
        XCTAssertThrowsError(
            try SplitAllocator.allocate(
                total: Money(cents: 1000),
                rule: .exact([josiah: Money(cents: 400), laura: Money(cents: 400)]),
                among: pair
            )
        ) { error in
            XCTAssertEqual(
                error as? SplitError,
                .exactAmountsMustSumToTotal(actual: Money(cents: 800), expected: Money(cents: 1000))
            )
        }
    }

    func testExactAmountsPassThroughWhenValid() throws {
        let allocation = try SplitAllocator.allocate(
            total: Money(cents: 1000),
            rule: .exact([josiah: Money(cents: 700), laura: Money(cents: 300)]),
            among: pair
        )
        XCTAssertEqual(allocation[josiah], Money(cents: 700))
        XCTAssertEqual(allocation[laura], Money(cents: 300))
    }

    func testRejectsStrangers() {
        XCTAssertThrowsError(
            try SplitAllocator.allocate(
                total: Money(cents: 1000),
                rule: .percentage(["someone-else": 100]),
                among: pair
            )
        ) { error in
            XCTAssertEqual(error as? SplitError, .unknownParticipant("someone-else"))
        }
    }

    func testRejectsEmptyParticipantsAndNegativeTotals() {
        XCTAssertThrowsError(
            try SplitAllocator.allocate(total: Money(cents: 100), rule: .equal, among: [])
        ) { XCTAssertEqual($0 as? SplitError, .noParticipants) }

        XCTAssertThrowsError(
            try SplitAllocator.allocate(total: Money(cents: -100), rule: .equal, among: pair)
        ) { XCTAssertEqual($0 as? SplitError, .negativeTotal) }
    }

    func testRejectsNonPositiveShares() {
        XCTAssertThrowsError(
            try SplitAllocator.allocate(
                total: Money(cents: 1000),
                rule: .shares([josiah: 1, laura: 0]),
                among: pair
            )
        ) { XCTAssertEqual($0 as? SplitError, .sharesMustBePositive) }
    }

    func testSplitRuleRoundTripsThroughCoding() throws {
        let rules: [SplitRule] = [
            .equal,
            .percentage([josiah: 60, laura: 40]),
            .exact([josiah: Money(cents: 600), laura: Money(cents: 400)]),
            .shares([josiah: 2, laura: 1]),
        ]
        for rule in rules {
            let data = try JSONEncoder().encode(rule)
            XCTAssertEqual(try JSONDecoder().decode(SplitRule.self, from: data), rule)
        }
    }
}

final class LedgerEntryTests: XCTestCase {
    func testExpenseBalancesBothSides() throws {
        let entry = try LedgerEntry.expense(
            id: "e1",
            ledgerId: book,
            amount: Money(cents: 8420),
            paidBy: josiah,
            splitRule: .equal,
            among: pair,
            note: "Groceries",
            createdBy: josiah
        )
        XCTAssertTrue(entry.isBalanced)
        XCTAssertEqual(entry.paidBy[josiah], Money(cents: 8420))
        XCTAssertEqual(entry.owedBy[josiah], Money(cents: 4210))
        XCTAssertEqual(entry.owedBy[laura], Money(cents: 4210))
    }

    func testExpenseDeltaIsPaidMinusOwed() throws {
        let entry = try LedgerEntry.expense(
            id: "e1",
            ledgerId: book,
            amount: Money(cents: 8420),
            paidBy: josiah,
            splitRule: .equal,
            among: pair,
            createdBy: josiah
        )
        XCTAssertEqual(entry.delta(for: josiah), Money(cents: 4210))
        XCTAssertEqual(entry.delta(for: laura), Money(cents: -4210))
    }

    func testSettlementBalancesBothSides() {
        let entry = LedgerEntry.settlement(
            id: "s1",
            ledgerId: book,
            from: laura,
            to: josiah,
            amount: Money(cents: 4210),
            createdBy: laura
        )
        XCTAssertTrue(entry.isBalanced)
        XCTAssertEqual(entry.delta(for: laura), Money(cents: 4210))
        XCTAssertEqual(entry.delta(for: josiah), Money(cents: -4210))
        XCTAssertNil(entry.splitRule)
    }

    func testOddCentExpenseStillBalances() throws {
        let entry = try LedgerEntry.expense(
            id: "e1",
            ledgerId: book,
            amount: Money(cents: 901),
            paidBy: laura,
            splitRule: .equal,
            among: pair,
            createdBy: laura
        )
        XCTAssertTrue(entry.isBalanced)
        XCTAssertEqual(entry.owedBy.values.total, Money(cents: 901))
    }

    func testEntryRoundTripsThroughCoding() throws {
        let entry = try LedgerEntry.expense(
            id: "e1",
            ledgerId: book,
            amount: Money(cents: 1234),
            paidBy: josiah,
            splitRule: .percentage([josiah: 60, laura: 40]),
            among: pair,
            note: "Dinner",
            category: "food",
            createdBy: josiah
        )
        let data = try JSONEncoder().encode(entry)
        XCTAssertEqual(try JSONDecoder().decode(LedgerEntry.self, from: data), entry)
    }

    func testSolePayer() throws {
        let entry = try LedgerEntry.expense(
            id: "e1",
            ledgerId: book,
            amount: Money(cents: 1000),
            paidBy: josiah,
            splitRule: .equal,
            among: pair,
            createdBy: josiah
        )
        XCTAssertEqual(entry.solePayer, josiah)
    }
}

final class BalanceTests: XCTestCase {

    private func expense(
        _ id: String,
        _ cents: Int,
        paidBy payer: String,
        rule: SplitRule = .equal
    ) throws -> LedgerEntry {
        try LedgerEntry.expense(
            id: id,
            ledgerId: book,
            amount: Money(cents: cents),
            paidBy: payer,
            splitRule: rule,
            among: pair,
            createdBy: payer
        )
    }

    func testNetPositionAcrossEntries() throws {
        let entries = [
            try expense("e1", 8420, paidBy: josiah),   // josiah +42.10
            try expense("e2", 6300, paidBy: laura),    // josiah −31.50
        ]
        XCTAssertEqual(Balance.net(for: josiah, in: entries), Money(cents: 1060))
        XCTAssertEqual(Balance.net(for: laura, in: entries), Money(cents: -1060))
    }

    func testBalancesAlwaysSumToZero() throws {
        let entries = [
            try expense("e1", 8420, paidBy: josiah),
            try expense("e2", 6300, paidBy: laura),
            try expense("e3", 901, paidBy: josiah),
            try expense("e4", 4999, paidBy: laura, rule: .percentage([josiah: 70, laura: 30])),
            LedgerEntry.settlement(
                id: "s1", ledgerId: book, from: laura, to: josiah,
                amount: Money(cents: 777), createdBy: laura
            ),
        ]
        let balances = Balance.all(for: pair, in: entries)
        XCTAssertEqual(balances.values.total, .zero)
    }

    func testEmptyLedgerIsSettled() {
        let standing = Balance.standing(viewer: josiah, partner: laura, in: [])
        XCTAssertTrue(standing.isSettled)
        XCTAssertNil(Balance.settlementNeeded(viewer: josiah, partner: laura, in: []))
    }

    func testSettlementNeededPointsTheRightWay() throws {
        // Josiah fronted the money, so Laura owes him.
        let entries = [try expense("e1", 8420, paidBy: josiah)]

        let owedToJosiah = Balance.settlementNeeded(viewer: josiah, partner: laura, in: entries)
        XCTAssertEqual(owedToJosiah?.from, laura)
        XCTAssertEqual(owedToJosiah?.to, josiah)
        XCTAssertEqual(owedToJosiah?.amount, Money(cents: 4210))

        // Same ledger seen from Laura's side describes the same transfer.
        let owedByLaura = Balance.settlementNeeded(viewer: laura, partner: josiah, in: entries)
        XCTAssertEqual(owedByLaura?.from, laura)
        XCTAssertEqual(owedByLaura?.to, josiah)
        XCTAssertEqual(owedByLaura?.amount, Money(cents: 4210))
    }

    func testSettlingClearsTheBalance() throws {
        var entries = [
            try expense("e1", 8420, paidBy: josiah),
            try expense("e2", 6300, paidBy: laura),
            try expense("e3", 901, paidBy: josiah),
        ]
        let transfer = try XCTUnwrap(
            Balance.settlementNeeded(viewer: josiah, partner: laura, in: entries)
        )
        entries.append(
            LedgerEntry.settlement(
                id: "s1",
                ledgerId: book,
                from: transfer.from,
                to: transfer.to,
                amount: transfer.amount,
                createdBy: transfer.from
            )
        )

        XCTAssertEqual(Balance.net(for: josiah, in: entries), .zero)
        XCTAssertEqual(Balance.net(for: laura, in: entries), .zero)
        XCTAssertNil(Balance.settlementNeeded(viewer: josiah, partner: laura, in: entries))
    }

    func testPartialSettlementLeavesTheRemainder() throws {
        var entries = [try expense("e1", 8420, paidBy: josiah)]
        entries.append(
            LedgerEntry.settlement(
                id: "s1", ledgerId: book, from: laura, to: josiah,
                amount: Money(cents: 1000), createdBy: laura
            )
        )
        XCTAssertEqual(Balance.net(for: josiah, in: entries), Money(cents: 3210))
    }

    func testStandingDescribesTheViewersSide() throws {
        let entries = [try expense("e1", 8420, paidBy: josiah)]

        let josiahSide = Balance.standing(viewer: josiah, partner: laura, in: entries)
        XCTAssertTrue(josiahSide.viewerIsOwed)
        XCTAssertEqual(josiahSide.magnitude, Money(cents: 4210))

        let lauraSide = Balance.standing(viewer: laura, partner: josiah, in: entries)
        XCTAssertFalse(lauraSide.viewerIsOwed)
        XCTAssertEqual(lauraSide.magnitude, Money(cents: 4210))
    }

    func testOrderOfEntriesDoesNotAffectBalance() throws {
        let entries = [
            try expense("e1", 8420, paidBy: josiah),
            try expense("e2", 6300, paidBy: laura),
            try expense("e3", 901, paidBy: josiah),
        ]
        XCTAssertEqual(
            Balance.net(for: josiah, in: entries),
            Balance.net(for: josiah, in: entries.reversed())
        )
    }
}
