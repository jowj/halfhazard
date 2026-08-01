//
//  LedgerStoreTests.swift
//  halfhazardTests
//

import XCTest
import FirebaseFirestore
@testable import halfhazard

private let josiah = "josiah"
private let laura = "laura"
private let book = "ledger-1"

/// A working ledger held in memory.
///
/// Not a mock: it stores entries, hands them back, and pushes a new snapshot to whoever is
/// listening, the same way Firestore does. Tests can therefore say "the other person added
/// an expense" and watch the store react, which is the behaviour that matters.
private final class InMemorySource: LedgerDataSource, @unchecked Sendable {
    var ledger: Ledger?
    var people: [User]
    private(set) var stored: [String: LedgerEntry] = [:]
    var failNextSave: Error?
    /// Reading the other member's profile is denied in production; this reproduces that.
    var failUsers = false
    private(set) var recordedNames: [String: String] = [:]

    private var continuations: [UUID: AsyncThrowingStream<[LedgerEntry], Error>.Continuation] = [:]
    private let lock = NSLock()

    init(ledger: Ledger?, people: [User] = [], entries: [LedgerEntry] = []) {
        self.ledger = ledger
        self.people = people
        for entry in entries { stored[entry.id] = entry }
    }

    func ledger(for userId: String) async throws -> Ledger? {
        ledger.flatMap { $0.contains(userId) ? $0 : nil }
    }

    func users(ids: [String]) async throws -> [User] {
        if failUsers {
            throw NSError(domain: "test", code: 7,
                          userInfo: [NSLocalizedDescriptionKey: "Missing or insufficient permissions."])
        }
        return people.filter { ids.contains($0.uid) }
    }

    private(set) var storedTemplates: [String: Template] = [:]
    private var templateContinuations: [UUID: AsyncThrowingStream<[Template], Error>.Continuation] = [:]

    func templates(in ledgerId: String) -> AsyncThrowingStream<[Template], Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            lock.withLock { templateContinuations[id] = continuation }
            continuation.yield(Array(storedTemplates.values))
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.templateContinuations.removeValue(forKey: id) }
            }
        }
    }

    func save(_ template: Template) async throws {
        storedTemplates[template.id] = template
        let all = Array(storedTemplates.values)
        for continuation in lock.withLock({ Array(templateContinuations.values) }) {
            continuation.yield(all)
        }
    }

    func deleteTemplate(id: String, from ledgerId: String) async throws {
        storedTemplates[id] = nil
        let all = Array(storedTemplates.values)
        for continuation in lock.withLock({ Array(templateContinuations.values) }) {
            continuation.yield(all)
        }
    }

    func recordName(_ name: String, for userId: String, in ledgerId: String) async throws {
        recordedNames[userId] = name
        ledger?.memberNames = recordedNames
    }

    func entries(in ledgerId: String) -> AsyncThrowingStream<[LedgerEntry], Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            lock.withLock { continuations[id] = continuation }
            continuation.yield(snapshot())
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.continuations.removeValue(forKey: id) }
            }
        }
    }

    func save(_ entry: LedgerEntry) async throws {
        if let failNextSave {
            self.failNextSave = nil
            throw failNextSave
        }
        stored[entry.id] = entry
        broadcast()
    }

    func delete(entryId: String, from ledgerId: String) async throws {
        stored[entryId] = nil
        broadcast()
    }

    private func snapshot() -> [LedgerEntry] {
        stored.values.sorted { $0.date > $1.date }
    }

    private func broadcast() {
        let entries = snapshot()
        let targets = lock.withLock { Array(continuations.values) }
        for continuation in targets { continuation.yield(entries) }
    }
}

private func user(_ id: String, name: String?) -> User {
    User(uid: id, displayName: name, email: "\(id)@example.com", groupIds: [],
         createdAt: Timestamp(), lastActive: Timestamp())
}

private func expense(
    id: String,
    amount: Int,
    paidBy payer: String,
    date: Date = Date(timeIntervalSince1970: 1_700_000_000)
) -> LedgerEntry {
    try! LedgerEntry.expense(
        id: id,
        ledgerId: book,
        amount: Money(cents: amount),
        paidBy: payer,
        splitRule: .equal,
        among: [josiah, laura],
        date: date,
        createdBy: payer
    )
}

@MainActor
final class LedgerStoreTests: XCTestCase {

    private func makeStore(
        entries: [LedgerEntry] = [],
        people: [User] = [user(josiah, name: "Josiah"), user(laura, name: "Laura")]
    ) async -> (LedgerStore, InMemorySource) {
        let source = InMemorySource(
            ledger: Ledger(id: book, memberIds: [josiah, laura]),
            people: people,
            entries: entries
        )
        let store = LedgerStore(source: source, viewerId: josiah)
        await store.start()
        await settle(store)
        return (store, source)
    }

    /// Lets the listener task deliver whatever is pending.
    private func settle(_ store: LedgerStore) async {
        for _ in 0..<20 where store.entries.isEmpty || store.isLoading {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }

    func testLoadsTheLedgerAndItsPeople() async {
        let (store, _) = await makeStore(entries: [expense(id: "a", amount: 8420, paidBy: josiah)])

        XCTAssertEqual(store.ledger?.id, book)
        XCTAssertEqual(store.partnerId, laura)
        XCTAssertEqual(store.name(for: josiah), "You")
        XCTAssertEqual(store.name(for: laura), "Laura")
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
    }

    func testBalanceComesFromTheEntries() async {
        let (store, _) = await makeStore(entries: [
            expense(id: "a", amount: 8420, paidBy: josiah),
            expense(id: "b", amount: 2000, paidBy: laura)
        ])

        // Josiah is owed half of 84.20 and owes half of 20.00.
        XCTAssertEqual(store.standing.amount, Money(cents: 3210))
        XCTAssertTrue(store.standing.viewerIsOwed)
        XCTAssertEqual(store.settlementNeeded?.from, laura)
        XCTAssertEqual(store.settlementNeeded?.amount, Money(cents: 3210))
    }

    /// The point of the rewrite: the other person's change arrives on its own, with no
    /// notification bus and nothing to refetch.
    func testAnEntryWrittenElsewhereArrivesOnItsOwn() async throws {
        let (store, source) = await makeStore(entries: [expense(id: "a", amount: 1000, paidBy: josiah)])
        XCTAssertEqual(store.entries.count, 1)

        try await source.save(expense(id: "b", amount: 5000, paidBy: laura))
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.standing.amount, Money(cents: -2000))
    }

    func testAddingAnExpenseDerivesWhatEachPersonOwes() async throws {
        let (store, _) = await makeStore()

        let entry = await store.addExpense(amount: Money(cents: 1001), paidBy: josiah, note: "coffee")
        try await Task.sleep(nanoseconds: 50_000_000)

        let saved = try XCTUnwrap(entry)
        XCTAssertEqual(saved.paidBy, [josiah: Money(cents: 1001)])
        XCTAssertEqual(saved.owedBy.values.total, Money(cents: 1001), "a stray cent has to go somewhere")
        XCTAssertEqual(saved.note, "coffee")
        XCTAssertEqual(store.entries.first?.id, saved.id, "and it shows up without a refresh")
    }

    func testSettlingWritesAnEntryRatherThanFlaggingOldOnes() async throws {
        let (store, _) = await makeStore(entries: [expense(id: "a", amount: 8420, paidBy: josiah)])

        let written = await store.settle()
        let settlement = try XCTUnwrap(written)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(settlement.kind, .settlement)
        XCTAssertEqual(settlement.amount, Money(cents: 4210))
        XCTAssertEqual(settlement.paidBy, [laura: Money(cents: 4210)])
        XCTAssertEqual(store.standing.amount, .zero)
        XCTAssertEqual(store.entries.count, 2, "the expense is still there — history is not rewritten")
        XCTAssertNil(store.settlementNeeded)
    }

    func testPartialSettlementLeavesTheRemainder() async throws {
        let (store, _) = await makeStore(entries: [expense(id: "a", amount: 10000, paidBy: josiah)])

        _ = await store.settle(amount: Money(cents: 2000))
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(store.standing.amount, Money(cents: 3000))
    }

    func testSettlingWithNothingOwedDoesNothing() async {
        let (store, source) = await makeStore()

        let settlement = await store.settle()

        XCTAssertNil(settlement)
        XCTAssertEqual(source.stored.count, 0)
        XCTAssertEqual(store.errorMessage, "Nothing to settle.")
    }

    /// Editing has to keep the entry's identity and re-derive the shares, or a corrected
    /// total leaves the halves disagreeing with it.
    func testEditingAnEntryKeepsItsIdentityAndRebalances() async throws {
        let (store, _) = await makeStore(entries: [expense(id: "a", amount: 8420, paidBy: josiah)])
        var edited = try XCTUnwrap(store.entries.first)
        let created = edited.createdAt

        edited.amount = Money(cents: 10_000)
        edited.owedBy = try SplitAllocator.allocate(total: Money(cents: 10_000), rule: .equal, among: [josiah, laura])
        edited.paidBy = [josiah: Money(cents: 10_000)]
        edited.note = "Groceries, corrected"
        await store.update(edited)
        try await Task.sleep(nanoseconds: 50_000_000)

        let stored = try XCTUnwrap(store.entries.first)
        XCTAssertEqual(store.entries.count, 1, "an edit replaces, it does not add")
        XCTAssertEqual(stored.id, "a")
        XCTAssertEqual(stored.createdAt, created, "when it was first recorded does not change")
        XCTAssertEqual(stored.note, "Groceries, corrected")
        XCTAssertTrue(stored.isBalanced)
        XCTAssertEqual(store.standing.amount, Money(cents: 5000))
    }

    func testDeletingRemovesItFromTheFeed() async throws {
        let (store, _) = await makeStore(entries: [
            expense(id: "a", amount: 1000, paidBy: josiah),
            expense(id: "b", amount: 2000, paidBy: laura)
        ])

        await store.delete(try XCTUnwrap(store.entries.first { $0.id == "b" }))
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(store.entries.map(\.id), ["a"])
        XCTAssertEqual(store.standing.amount, Money(cents: 500))
    }

    func testAFailedWriteSurfacesAsAMessage() async {
        let (store, source) = await makeStore()
        source.failNextSave = NSError(
            domain: "test", code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Missing or insufficient permissions."]
        )

        let entry = await store.addExpense(amount: Money(cents: 500), paidBy: josiah)

        XCTAssertNil(entry)
        XCTAssertEqual(store.errorMessage, "Missing or insufficient permissions.")
    }

    func testFeedIsNewestFirstAndGroupedByDay() async {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let (store, _) = await makeStore(entries: [
            expense(id: "a", amount: 1000, paidBy: josiah, date: day),
            expense(id: "b", amount: 2000, paidBy: laura, date: day.addingTimeInterval(60)),
            expense(id: "c", amount: 3000, paidBy: josiah, date: day.addingTimeInterval(-86_400))
        ])

        XCTAssertEqual(store.entries.map(\.id), ["b", "a", "c"])
        XCTAssertEqual(store.entriesByDay.count, 2)
        XCTAssertEqual(store.entriesByDay.first?.entries.map(\.id), ["b", "a"])
    }

    func testNoLedgerYetIsAnEmptyStateRatherThanAnError() async {
        let source = InMemorySource(ledger: nil)
        let store = LedgerStore(source: source, viewerId: josiah)

        await store.start()

        XCTAssertNil(store.ledger)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
    }

    /// Shipped broken once: `users/{id}` is readable only by that user, so loading the other
    /// member's profile is denied — and the store treated that as fatal, so a ledger whose
    /// entries had loaded fine came up empty behind a permissions error.
    func testADeniedProfileReadDoesNotCostTheLedger() async {
        let source = InMemorySource(
            ledger: Ledger(id: book, memberIds: [josiah, laura]),
            people: [user(josiah, name: "Josiah")],
            entries: [expense(id: "a", amount: 8420, paidBy: josiah)]
        )
        source.failUsers = true
        let store = LedgerStore(source: source, viewerId: josiah)

        await store.start()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(store.entries.count, 1, "the entries were readable and must still arrive")
        XCTAssertEqual(store.standing.amount, Money(cents: 4210))
        XCTAssertNil(store.errorMessage, "a missing name is not an error worth a banner")
        XCTAssertEqual(store.name(for: laura), "Them")
    }

    /// Each side publishes its own name onto the ledger, because neither can read the
    /// other's profile document.
    func testPublishesItsOwnNameOntoTheLedger() async {
        let (store, source) = await makeStore()

        XCTAssertEqual(source.recordedNames[josiah], "Josiah")
        XCTAssertNil(source.recordedNames[laura], "it publishes only its own")
        XCTAssertEqual(store.name(for: josiah), "You")
    }

    func testPrefersTheNamePublishedOnTheLedger() async {
        let source = InMemorySource(
            ledger: Ledger(id: book, memberIds: [josiah, laura], memberNames: [laura: "Laura"]),
            people: [user(josiah, name: "Josiah")],
            entries: [expense(id: "a", amount: 1000, paidBy: josiah)]
        )
        source.failUsers = true
        let store = LedgerStore(source: source, viewerId: josiah)

        await store.start()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(store.name(for: laura), "Laura", "readable without touching her profile")
    }

    /// Renaming yourself has to reach the ledger: the other person's client cannot read your
    /// profile, so an unpublished change is invisible to them.
    func testRefreshingTheProfilePublishesTheNewName() async {
        let (store, source) = await makeStore()
        XCTAssertEqual(source.recordedNames[josiah], "Josiah")

        source.people = [user(josiah, name: "Jos"), user(laura, name: "Laura")]
        await store.refreshProfile()

        XCTAssertEqual(source.recordedNames[josiah], "Jos")
        XCTAssertEqual(store.viewer?.displayName, "Jos")
    }

    func testRefreshingPublishesEvenWhenNobodyHasBeenNamedYet() async {
        let source = InMemorySource(
            ledger: Ledger(id: book, memberIds: [josiah, laura]),
            people: [user(josiah, name: "Josiah")],
            entries: [expense(id: "a", amount: 1000, paidBy: josiah)]
        )
        let store = LedgerStore(source: source, viewerId: josiah)
        await store.start()
        try? await Task.sleep(nanoseconds: 50_000_000)

        await store.refreshProfile()

        XCTAssertEqual(store.ledger?.memberNames?[josiah], "Josiah")
    }

    func testFallsBackToASensibleNameWhenTheUserIsUnknown() async {
        let (store, _) = await makeStore(people: [user(josiah, name: "Josiah"), user(laura, name: nil)])

        XCTAssertEqual(store.name(for: laura), "laura", "the email's local part beats a blank row")
        XCTAssertEqual(store.name(for: "nobody"), "Them")
    }
}

@MainActor
final class LedgerStoreTemplateTests: XCTestCase {

    private func makeStore(templates: [Template] = []) async -> (LedgerStore, InMemorySource) {
        let source = InMemorySource(
            ledger: Ledger(id: book, memberIds: [josiah, laura]),
            people: [user(josiah, name: "Josiah"), user(laura, name: "Laura")]
        )
        for template in templates { try? await source.save(template) }
        let store = LedgerStore(source: source, viewerId: josiah)
        await store.start()
        try? await Task.sleep(nanoseconds: 50_000_000)
        return (store, source)
    }

    private var monthly: Template {
        Template(
            id: "t1", ledgerId: book, name: "Monthly",
            lines: [
                TemplateLine(id: "l1", note: "Rent", amount: Money(cents: 200_000),
                             payer: .member(josiah),
                             split: .percentage([josiah: 70, laura: 30])),
                TemplateLine(id: "l2", note: "Internet", amount: Money(cents: 8000))
            ],
            createdBy: josiah
        )
    }

    func testTemplatesArriveOnTheirOwnListener() async {
        let (store, _) = await makeStore(templates: [monthly])

        XCTAssertEqual(store.templates.map(\.name), ["Monthly"])
        XCTAssertEqual(store.templates.first?.total, Money(cents: 208_000))
    }

    func testApplyingWritesOneEntryPerLine() async throws {
        let (store, _) = await makeStore(templates: [monthly])

        let written = await store.apply(monthly)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(written?.count, 2)
        XCTAssertEqual(store.entries.count, 2)

        let rent = try XCTUnwrap(store.entries.first { $0.note == "Rent" })
        XCTAssertEqual(rent.owedBy[josiah], Money(cents: 140_000), "70% to the person named")
        XCTAssertEqual(rent.owedBy[laura], Money(cents: 60_000))
        XCTAssertEqual(rent.solePayer, josiah)

        let internet = try XCTUnwrap(store.entries.first { $0.note == "Internet" })
        XCTAssertEqual(internet.solePayer, josiah, "the applier fronted this one")
        XCTAssertEqual(internet.owedBy[laura], Money(cents: 4000))
    }

    func testApplyingMovesTheBalance() async throws {
        let (store, _) = await makeStore(templates: [monthly])

        await store.apply(monthly)
        try await Task.sleep(nanoseconds: 50_000_000)

        // Josiah fronts $2,080.00 and owes $1,400.00 of the rent plus $40.00 of the internet.
        XCTAssertEqual(store.standing.amount, Money(cents: 64_000))
    }

    func testAStaleTemplateReportsRatherThanMisallocating() async throws {
        let stale = Template(
            id: "t2", ledgerId: book, name: "Stale",
            lines: [TemplateLine(note: "Rent", amount: Money(cents: 1000),
                                 split: .percentage(["departed": 100]))],
            createdBy: josiah
        )
        let (store, _) = await makeStore(templates: [stale])

        let written = await store.apply(stale)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(written)
        XCTAssertTrue(store.entries.isEmpty, "nothing is written when the template no longer fits")
        XCTAssertNotNil(store.errorMessage)
    }

    func testSavingAndDeletingATemplate() async throws {
        let (store, source) = await makeStore()

        await store.save(monthly)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(store.templates.count, 1)

        await store.delete(monthly)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(store.templates.isEmpty)
        XCTAssertTrue(source.storedTemplates.isEmpty)
    }

    func testANewTemplateIsBoundToTheLedger() async {
        let (store, _) = await makeStore()

        let fresh = store.newTemplate(name: "Weekly")

        XCTAssertEqual(fresh?.ledgerId, book)
        XCTAssertEqual(fresh?.createdBy, josiah)
        XCTAssertTrue(fresh?.lines.isEmpty ?? false)
    }
}

@MainActor
final class LedgerStoreTransferTests: XCTestCase {

    private func makeStore(entries: [LedgerEntry]) async -> (LedgerStore, InMemorySource) {
        let source = InMemorySource(
            ledger: Ledger(id: book, memberIds: [josiah, laura]),
            people: [user(josiah, name: "Josiah"), user(laura, name: "Laura")],
            entries: entries
        )
        let store = LedgerStore(source: source, viewerId: josiah)
        await store.start()
        try? await Task.sleep(nanoseconds: 50_000_000)
        return (store, source)
    }

    private var sample: [LedgerEntry] {
        [expense(id: "a", amount: 8420, paidBy: josiah),
         expense(id: "b", amount: 1250, paidBy: laura)]
    }

    func testExportsBothFormats() async throws {
        let (store, _) = await makeStore(entries: sample)

        let csv = try XCTUnwrap(store.exported(as: .csv))
        let json = try XCTUnwrap(store.exported(as: .json))

        let text = String(decoding: csv, as: UTF8.self)
        XCTAssertTrue(text.contains("paid_You") || text.contains("paid_Laura"))
        XCTAssertEqual(text.components(separatedBy: "\n").count, 3, "a header and two rows")
        XCTAssertTrue(String(decoding: json, as: UTF8.self).contains("\"ledgerId\""))
    }

    /// The round trip that matters: export, import, and the ledger is unchanged rather than
    /// doubled, because the ids travel with the file.
    func testImportingItsOwnExportChangesNothing() async throws {
        let (store, source) = await makeStore(entries: sample)
        let data = try XCTUnwrap(store.exported(as: .json))

        let preview = store.preview(data, named: "ledger.json")
        XCTAssertTrue(preview.issues.isEmpty)
        let written = await store.importEntries(preview.entries)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(written, 2)
        XCTAssertEqual(store.entries.count, 2, "replaced, not added again")
        XCTAssertEqual(source.stored.count, 2)
        XCTAssertEqual(store.standing.amount, Money(cents: 3585))
    }

    func testImportingACSVSomebodyTyped() async throws {
        let (store, _) = await makeStore(entries: [])
        let text = """
        date,description,amount,paid_You,owed_You,owed_Laura
        2026-03-14,Pie,20.00,20.00,10.00,10.00
        """

        let preview = store.preview(Data(text.utf8), named: "typed.csv")
        let written = await store.importEntries(preview.entries)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(written, 1)
        XCTAssertEqual(store.entries.first?.note, "Pie")
        XCTAssertEqual(store.standing.amount, Money(cents: 1000))
    }

    func testPreviewWritesNothingUntilItIsAccepted() async throws {
        let (store, source) = await makeStore(entries: [])
        let text = """
        date,description,amount,paid_You,owed_You,owed_Laura
        2026-03-14,Pie,20.00,20.00,10.00,10.00
        """

        _ = store.preview(Data(text.utf8), named: "typed.csv")
        try await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertTrue(source.stored.isEmpty, "a preview is a look, not a write")
    }

    func testAFileFullOfNonsenseIsReportedNotWritten() async {
        let (store, source) = await makeStore(entries: [])

        let preview = store.preview(Data("hello".utf8), named: "notes.json")

        XCTAssertTrue(preview.entries.isEmpty)
        XCTAssertFalse(preview.issues.isEmpty)
        XCTAssertTrue(source.stored.isEmpty)
    }
}
