//
//  BalancePhrasingTests.swift
//  halfhazardTests
//

import XCTest
@testable import halfhazard

private let josiah = "josiah"
private let laura = "laura"

// `name` on its own would resolve to XCTestCase.name, which is a String.
private func displayName(_ id: String) -> String {
    id == josiah ? "Josiah" : "Laura"
}

/// The rewrite exists partly because these sentences used to come out backwards: the old row
/// labelled the other person's expense "You Paid", because the label keyed off a split type
/// that meant "relative to whoever typed it in". Every phrase is checked from both sides.
final class BalancePhrasingTests: XCTestCase {

    func testHeadlineReadsCorrectlyFromEitherSide() {
        let owed = Balance.Standing(amount: Money(cents: 3210), partner: laura)
        let owing = Balance.Standing(amount: Money(cents: -3210), partner: josiah)

        XCTAssertEqual(owed.sentence(partnerName: "Laura"), "Laura owes you $32.10")
        XCTAssertEqual(owing.sentence(partnerName: "Josiah"), "You owe Josiah $32.10")
    }

    func testSettledHeadlineDoesNotNameAnAmount() {
        let settled = Balance.Standing(amount: .zero, partner: laura)

        XCTAssertEqual(settled.sentence(partnerName: "Laura"), "You're square")
        XCTAssertEqual(settled.shortForm, "settled")
    }

    /// The same entry, described to each person. Neither should be told they paid when they
    /// did not.
    func testPayerSentenceIsRelativeToTheViewerNotTheCreator() throws {
        let entry = try LedgerEntry.expense(
            id: "e", ledgerId: "l", amount: Money(cents: 8420), paidBy: laura,
            splitRule: .equal, among: [josiah, laura], note: "Groceries",
            createdBy: josiah  // Josiah typed it in; Laura paid.
        )

        XCTAssertEqual(entry.payerSentence(viewer: josiah, name: displayName), "Laura paid")
        XCTAssertEqual(entry.payerSentence(viewer: laura, name: displayName), "You paid")
    }

    func testSettlementSentenceNamesTheDirection() {
        let settlement = LedgerEntry.settlement(
            id: "s", ledgerId: "l", from: laura, to: josiah,
            amount: Money(cents: 4210), createdBy: laura
        )

        XCTAssertEqual(settlement.settlementSentence(viewer: josiah, name: displayName), "Laura paid you $42.10")
        XCTAssertEqual(settlement.settlementSentence(viewer: laura, name: displayName), "You paid Josiah $42.10")
    }

    func testDeltaLabelIsSignedFromTheViewersSide() throws {
        let entry = try LedgerEntry.expense(
            id: "e", ledgerId: "l", amount: Money(cents: 8420), paidBy: josiah,
            splitRule: .equal, among: [josiah, laura], createdBy: josiah
        )

        XCTAssertEqual(entry.deltaLabel(for: josiah), "+$42.10")
        XCTAssertEqual(entry.deltaLabel(for: laura), "-$42.10")
    }

    func testAnEntryThatDoesNotMoveTheViewerReadsAsNothing() throws {
        let entry = try LedgerEntry.expense(
            id: "e", ledgerId: "l", amount: Money(cents: 1000), paidBy: josiah,
            splitRule: .exact([josiah: Money(cents: 1000), laura: .zero]),
            among: [josiah, laura], createdBy: josiah
        )

        XCTAssertEqual(entry.deltaLabel(for: laura), "—", "she neither paid nor owes anything")
        XCTAssertEqual(entry.deltaLabel(for: josiah), "—", "he paid for what he alone owed")
    }
}

/// The edit screen reads an entry's split back as a choice. Getting this wrong would flatten
/// an uneven split to 50/50 the next time somebody corrected a typo in the note.
final class SplitShapeTests: XCTestCase {

    private func entry(owedBy: [String: Money], amount: Int) -> LedgerEntry {
        LedgerEntry(
            id: "e", ledgerId: "l", kind: .expense, amount: Money(cents: amount),
            paidBy: [josiah: Money(cents: amount)], owedBy: owedBy,
            note: nil, category: nil, splitRule: nil,
            date: Date(), createdAt: Date(), createdBy: josiah
        )
    }

    func testAnEvenSplitReadsAsEven() {
        let even = entry(owedBy: [josiah: Money(cents: 4210), laura: Money(cents: 4210)], amount: 8420)

        XCTAssertEqual(SplitShape.of(even, viewer: josiah), .evenly)
    }

    func testAnOddCentStillReadsAsEven() {
        let odd = entry(owedBy: [josiah: Money(cents: 501), laura: Money(cents: 500)], amount: 1001)

        XCTAssertEqual(SplitShape.of(odd, viewer: josiah), .evenly, "one leftover cent is what even looks like")
    }

    func testOneSideCoveringItAll() {
        let mine = entry(owedBy: [josiah: Money(cents: 3000), laura: .zero], amount: 3000)
        let theirs = entry(owedBy: [josiah: .zero, laura: Money(cents: 3000)], amount: 3000)

        XCTAssertEqual(SplitShape.of(mine, viewer: josiah), .allViewer)
        XCTAssertEqual(SplitShape.of(theirs, viewer: josiah), .allPartner)
    }

    /// The case that matters: a 70/30 from a template must not be mistaken for anything the
    /// three simple options can express.
    func testAnUnevenSplitIsRecognisedAsRecorded() {
        let uneven = entry(owedBy: [josiah: Money(cents: 140_000), laura: Money(cents: 60_000)],
                           amount: 200_000)

        XCTAssertEqual(SplitShape.of(uneven, viewer: josiah), .asRecorded)
    }

    func testItReadsTheSameFromEitherSide() {
        let uneven = entry(owedBy: [josiah: Money(cents: 140_000), laura: Money(cents: 60_000)],
                           amount: 200_000)

        XCTAssertEqual(SplitShape.of(uneven, viewer: laura), .asRecorded)
    }
}
