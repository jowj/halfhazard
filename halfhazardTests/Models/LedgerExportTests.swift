//
//  LedgerExportTests.swift
//  halfhazardTests
//

import XCTest
@testable import halfhazard

private let josiah = "josiah"
private let laura = "laura"
private let pair = [josiah, laura]
private let book = "ledger-1"

private func displayName(_ id: String) -> String {
    id == josiah ? "Josiah" : "Laura"
}

private func expense(
    id: String = "e1",
    cents: Int,
    paidBy payer: String = josiah,
    rule: SplitRule = .equal,
    note: String? = "Groceries",
    category: String? = nil,
    date: Date = Date(timeIntervalSince1970: 1_700_000_000)
) -> LedgerEntry {
    try! LedgerEntry.expense(
        id: id, ledgerId: book, amount: Money(cents: cents), paidBy: payer,
        splitRule: rule, among: pair, note: note, category: category,
        date: date, createdAt: date, createdBy: payer
    )
}

final class LedgerExportTests: XCTestCase {

    // MARK: - JSON

    func testJSONRoundTripsExactly() throws {
        let entries = [
            expense(id: "a", cents: 8420),
            expense(id: "b", cents: 200_000, rule: .percentage([josiah: 70, laura: 30]), note: "Rent"),
            LedgerEntry.settlement(id: "c", ledgerId: book, from: laura, to: josiah,
                                   amount: Money(cents: 4210), note: "Venmo",
                                   date: Date(timeIntervalSince1970: 1_700_100_000),
                                   createdAt: Date(timeIntervalSince1970: 1_700_100_000),
                                   createdBy: laura)
        ]

        let data = try LedgerExport.json(entries)
        let result = LedgerExport.fromJSON(data, ledgerId: book, members: pair, importedBy: josiah)

        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(Set(result.entries.map(\.id)), ["a", "b", "c"])
        let rent = try XCTUnwrap(result.entries.first { $0.id == "b" })
        XCTAssertEqual(rent.splitRule, .percentage([josiah: 70, laura: 30]), "the rule survives, not just the amounts")
        XCTAssertEqual(rent.owedBy[josiah], Money(cents: 140_000))
        XCTAssertEqual(Balance.net(for: josiah, in: entries), Balance.net(for: josiah, in: result.entries))
    }

    func testJSONFromAnotherLedgerIsRehomed() throws {
        let elsewhere = try! LedgerEntry.expense(
            id: "x", ledgerId: "some-other-book", amount: Money(cents: 1000), paidBy: josiah,
            splitRule: .equal, among: pair, createdBy: josiah
        )

        let data = try LedgerExport.json([elsewhere])
        let result = LedgerExport.fromJSON(data, ledgerId: book, members: pair, importedBy: josiah)

        XCTAssertEqual(result.entries.first?.ledgerId, book)
    }

    func testJSONRejectsEntriesNamingStrangers() throws {
        let stranger = LedgerEntry(
            id: "x", ledgerId: book, kind: .expense, amount: Money(cents: 1000),
            paidBy: ["someone-else": Money(cents: 1000)],
            owedBy: [josiah: Money(cents: 1000)],
            note: "Odd one", category: nil, splitRule: nil,
            date: Date(), createdAt: Date(), createdBy: josiah
        )

        let data = try LedgerExport.json([stranger])
        let result = LedgerExport.fromJSON(data, ledgerId: book, members: pair, importedBy: josiah)

        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertTrue(result.issues[0].message.contains("someone-else"))
    }

    func testJSONRejectsAnUnbalancedEntry() throws {
        let wrong = LedgerEntry(
            id: "x", ledgerId: book, kind: .expense, amount: Money(cents: 1000),
            paidBy: [josiah: Money(cents: 1000)],
            owedBy: [josiah: Money(cents: 400), laura: Money(cents: 400)],
            note: "Does not add up", category: nil, splitRule: nil,
            date: Date(), createdAt: Date(), createdBy: josiah
        )

        let data = try LedgerExport.json([wrong])
        let result = LedgerExport.fromJSON(data, ledgerId: book, members: pair, importedBy: josiah)

        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.issues.count, 1)
    }

    func testRubbishIsNotALedger() {
        let result = LedgerExport.fromJSON(Data("not json".utf8), ledgerId: book,
                                           members: pair, importedBy: josiah)

        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.issues.first?.message, "This is not a ledger export.")
    }

    // MARK: - CSV

    func testCSVHasAColumnPerPersonAndReadsBack() {
        let entries = [expense(id: "a", cents: 8420), expense(id: "b", cents: 1250, paidBy: laura, note: "Coffee")]

        let text = LedgerExport.csv(entries, members: pair, name: displayName)
        let header = LedgerExport.parseRow(text.components(separatedBy: "\n")[0])

        XCTAssertTrue(header.contains("paid_Josiah"))
        XCTAssertTrue(header.contains("owed_Laura"))

        let result = LedgerExport.fromCSV(text, ledgerId: book, members: pair,
                                          importedBy: josiah, name: displayName)

        XCTAssertTrue(result.issues.isEmpty, "\(result.issues)")
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(Balance.net(for: josiah, in: result.entries),
                       Balance.net(for: josiah, in: entries), "the money survives the trip")
    }

    /// Re-importing an export must not double the ledger, so ids travel in the file.
    func testCSVKeepsIdsSoReimportingOverwrites() {
        let entries = [expense(id: "a", cents: 8420)]
        let text = LedgerExport.csv(entries, members: pair, name: displayName)

        let result = LedgerExport.fromCSV(text, ledgerId: book, members: pair,
                                          importedBy: josiah, name: displayName)

        XCTAssertEqual(result.entries.first?.id, "a")
    }

    func testCSVSurvivesCommasAndQuotesInDescriptions() {
        let entries = [expense(id: "a", cents: 1000, note: "Dinner, with \"the good\" wine")]

        let text = LedgerExport.csv(entries, members: pair, name: displayName)
        let result = LedgerExport.fromCSV(text, ledgerId: book, members: pair,
                                          importedBy: josiah, name: displayName)

        XCTAssertEqual(result.entries.first?.note, "Dinner, with \"the good\" wine")
    }

    func testCSVCarriesSettlementsAsSettlements() {
        let settlement = LedgerEntry.settlement(id: "s", ledgerId: book, from: laura, to: josiah,
                                                amount: Money(cents: 4210), createdBy: laura)

        let text = LedgerExport.csv([settlement], members: pair, name: displayName)
        let result = LedgerExport.fromCSV(text, ledgerId: book, members: pair,
                                          importedBy: josiah, name: displayName)

        XCTAssertEqual(result.entries.first?.kind, .settlement)
        XCTAssertEqual(result.entries.first?.paidBy, [laura: Money(cents: 4210)])
    }

    /// A row a person typed by hand, which is the point of accepting CSV at all.
    func testAHandWrittenRowIsAccepted() {
        let text = """
        date,description,amount,paid_Josiah,owed_Josiah,owed_Laura
        2026-03-14,Pie,20.00,20.00,10.00,10.00
        """

        let result = LedgerExport.fromCSV(text, ledgerId: book, members: pair,
                                          importedBy: josiah, name: displayName,
                                          makeId: { "generated" })

        XCTAssertTrue(result.issues.isEmpty, "\(result.issues)")
        let entry = result.entries.first
        XCTAssertEqual(entry?.id, "generated", "a row with no id gets one")
        XCTAssertEqual(entry?.amount, Money(cents: 2000))
        XCTAssertEqual(entry?.note, "Pie")
        XCTAssertEqual(entry?.createdBy, josiah, "whoever imported it recorded it")
        XCTAssertTrue(entry?.isBalanced ?? false)
    }

    func testABadRowIsReportedAndTheRestStillImport() {
        let text = """
        date,description,amount,paid_Josiah,owed_Josiah,owed_Laura
        2026-03-14,Fine,20.00,20.00,10.00,10.00
        2026-03-15,Bad total,20.00,20.00,5.00,5.00
        2026-03-16,No amount,,,,
        2026-03-17,Also fine,10.00,10.00,5.00,5.00
        """

        let result = LedgerExport.fromCSV(text, ledgerId: book, members: pair,
                                          importedBy: josiah, name: displayName)

        XCTAssertEqual(result.entries.count, 2, "one bad row does not cost the good ones")
        XCTAssertEqual(result.issues.count, 2)
        XCTAssertEqual(result.issues.map(\.row), [3, 4], "rows are numbered as the spreadsheet shows them")
        XCTAssertTrue(result.issues[0].message.contains("owed columns"))
    }

    func testAFileWithNoColumnsForThesePeopleSaysSo() {
        let text = """
        date,description,amount,paid_Somebody,owed_Somebody
        2026-03-14,Pie,20.00,20.00,20.00
        """

        let result = LedgerExport.fromCSV(text, ledgerId: book, members: pair,
                                          importedBy: josiah, name: displayName)

        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertTrue(result.issues.first?.message.contains("paid_/owed_ columns") ?? false)
    }

    func testColumnsCanBeKeyedByUserIdWhenNamesHaveChanged() {
        let text = """
        date,description,amount,paid_josiah,owed_josiah,owed_laura
        2026-03-14,Pie,20.00,20.00,10.00,10.00
        """

        // Names have changed since the file was written; the ids still match.
        let result = LedgerExport.fromCSV(text, ledgerId: book, members: pair,
                                          importedBy: josiah, name: { _ in "Someone Else" })

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries.first?.owedBy[laura], Money(cents: 1000))
    }

    func testAnEmptyFileIsNotAnImport() {
        let result = LedgerExport.fromCSV("date,amount\n", ledgerId: book, members: pair,
                                          importedBy: josiah, name: displayName)

        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertFalse(result.issues.isEmpty)
    }

    func testCentsSurviveTheRoundTrip() {
        // A three-way-ish split of an odd amount: the parts differ by a cent.
        let entries = [expense(id: "a", cents: 1001)]

        let text = LedgerExport.csv(entries, members: pair, name: displayName)
        let result = LedgerExport.fromCSV(text, ledgerId: book, members: pair,
                                          importedBy: josiah, name: displayName)

        XCTAssertEqual(result.entries.first?.owedBy.values.total, Money(cents: 1001))
        XCTAssertEqual(Set(result.entries.first?.owedBy.values.map(\.cents) ?? []), [501, 500])
    }
}
