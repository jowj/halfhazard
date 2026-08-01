//
//  TemplateTests.swift
//  halfhazardTests
//

import XCTest
@testable import halfhazard

private let josiah = "josiah"
private let laura = "laura"
private let pair = [josiah, laura]
private let book = "ledger-1"

private func template(_ lines: [TemplateLine], name: String = "Monthly") -> Template {
    Template(id: "t1", ledgerId: book, name: name, lines: lines, createdBy: josiah)
}

final class TemplateTests: XCTestCase {

    func testAppliesAnEvenlySplitLine() throws {
        let subject = template([
            TemplateLine(note: "Internet", amount: Money(cents: 8000))
        ])

        let entries = try subject.entries(appliedBy: josiah, among: pair, id: { _ in "e1" })
        let entry = try XCTUnwrap(entries.first)

        XCTAssertEqual(entry.amount, Money(cents: 8000))
        XCTAssertEqual(entry.paidBy, [josiah: Money(cents: 8000)])
        XCTAssertEqual(entry.owedBy, [josiah: Money(cents: 4000), laura: Money(cents: 4000)])
        XCTAssertEqual(entry.note, "Internet")
        XCTAssertTrue(entry.isBalanced)
    }

    /// The defect this replaces: percentages were mapped onto members by array index, from
    /// `Array(percentages.keys)` — a dictionary's order — so who got 70% was arbitrary, and
    /// could differ between two runs of the same template. Keyed by user id, it cannot drift.
    func testPercentagesGoToThePersonTheyName() throws {
        let subject = template([
            TemplateLine(
                note: "Rent",
                amount: Money(cents: 200_000),
                split: .percentage([josiah: 70, laura: 30])
            )
        ])

        // Members in one order, and then the other. The result must not depend on it.
        let forwards = try subject.entries(appliedBy: josiah, among: [josiah, laura], id: { _ in "e" })
        let backwards = try subject.entries(appliedBy: josiah, among: [laura, josiah], id: { _ in "e" })

        XCTAssertEqual(forwards.first?.owedBy[josiah], Money(cents: 140_000))
        XCTAssertEqual(forwards.first?.owedBy[laura], Money(cents: 60_000))
        XCTAssertEqual(forwards.first?.owedBy, backwards.first?.owedBy)
    }

    func testExactAndSharesRulesSurviveTheRoundTrip() throws {
        let subject = template([
            TemplateLine(note: "Groceries", amount: Money(cents: 10_000),
                         split: .exact([josiah: Money(cents: 6000), laura: Money(cents: 4000)])),
            TemplateLine(note: "Car", amount: Money(cents: 9000), split: .shares([josiah: 2, laura: 1]))
        ])

        let entries = try subject.entries(appliedBy: josiah, among: pair)

        XCTAssertEqual(entries[0].owedBy, [josiah: Money(cents: 6000), laura: Money(cents: 4000)])
        XCTAssertEqual(entries[1].owedBy, [josiah: Money(cents: 6000), laura: Money(cents: 3000)])
    }

    // MARK: - Who pays

    func testApplierPaysByDefault() throws {
        let subject = template([TemplateLine(note: "Coffee", amount: Money(cents: 500))])

        let byJosiah = try subject.entries(appliedBy: josiah, among: pair)
        let byLaura = try subject.entries(appliedBy: laura, among: pair)

        XCTAssertEqual(byJosiah.first?.solePayer, josiah)
        XCTAssertEqual(byLaura.first?.solePayer, laura, "whoever applies it is the one who paid")
    }

    func testAFixedPayerStaysFixedWhoeverAppliesIt() throws {
        let subject = template([
            TemplateLine(note: "Internet", amount: Money(cents: 8000), payer: .member(josiah))
        ])

        let byLaura = try subject.entries(appliedBy: laura, among: pair)

        XCTAssertEqual(byLaura.first?.solePayer, josiah, "it is on Josiah's card either way")
        XCTAssertEqual(byLaura.first?.createdBy, laura, "though Laura is the one who recorded it")
    }

    // MARK: - Guards

    /// A template outliving a change in who is on the ledger must fail rather than quietly
    /// hand somebody else's share to whoever is left.
    func testASplitNamingSomebodyElseThrows() {
        let subject = template([
            TemplateLine(note: "Rent", amount: Money(cents: 1000),
                         split: .percentage(["someone-else": 100]))
        ])

        XCTAssertThrowsError(try subject.entries(appliedBy: josiah, among: pair)) { error in
            XCTAssertEqual(error as? SplitError, .unknownParticipant("someone-else"))
        }
    }

    func testPercentagesThatDoNotAddUpThrow() {
        let subject = template([
            TemplateLine(note: "Rent", amount: Money(cents: 1000),
                         split: .percentage([josiah: 60, laura: 30]))
        ])

        XCTAssertThrowsError(try subject.entries(appliedBy: josiah, among: pair))
    }

    // MARK: - Whole template

    func testTotalAddsUpTheLines() {
        let subject = template([
            TemplateLine(note: "Rent", amount: Money(cents: 200_000)),
            TemplateLine(note: "Internet", amount: Money(cents: 8000)),
            TemplateLine(note: "Power", amount: Money(cents: 4550))
        ])

        XCTAssertEqual(subject.total, Money(cents: 212_550))
    }

    func testApplyingProducesOneEntryPerLineWithDistinctIds() throws {
        let subject = template([
            TemplateLine(note: "Rent", amount: Money(cents: 200_000)),
            TemplateLine(note: "Internet", amount: Money(cents: 8000))
        ])

        let entries = try subject.entries(appliedBy: josiah, among: pair)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(Set(entries.map(\.id)).count, 2)
        XCTAssertEqual(entries.map(\.ledgerId), [book, book])
        XCTAssertEqual(Balance.net(for: josiah, in: entries), Money(cents: 104_000))
    }

    func testApplyingTwiceMakesTwoSetsOfEntries() throws {
        let subject = template([TemplateLine(note: "Rent", amount: Money(cents: 1000))])

        let first = try subject.entries(appliedBy: josiah, among: pair)
        let second = try subject.entries(appliedBy: josiah, among: pair)

        XCTAssertNotEqual(first.first?.id, second.first?.id, "this month's rent is not last month's")
    }

    func testEncodesToAReadableShape() throws {
        let subject = template([
            TemplateLine(id: "l1", note: "Rent", amount: Money(cents: 200_000),
                         payer: .member(josiah), split: .percentage([josiah: 70, laura: 30]))
        ])

        let data = try JSONEncoder().encode(subject)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"kind\":\"member\""))
        XCTAssertTrue(json.contains("\"type\":\"percentage\""))

        let decoded = try JSONDecoder().decode(Template.self, from: data)
        XCTAssertEqual(decoded, subject)
    }
}
