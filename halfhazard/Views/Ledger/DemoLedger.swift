//
//  DemoLedger.swift
//  halfhazard
//

#if DEBUG
import Foundation
import SwiftUI

/// A ledger with plausible contents and no network behind it.
///
/// For previews, and for looking at the screen on a simulator without signing in — launch
/// with `-demoLedger`. Debug builds only; it is not compiled into a release.
final class DemoLedgerSource: LedgerDataSource, @unchecked Sendable {
    static let viewerId = "you"
    static let partnerId = "them"

    private var entries: [LedgerEntry]
    private var continuations: [UUID: AsyncThrowingStream<[LedgerEntry], Error>.Continuation] = [:]

    init() {
        let ledgerId = "demo"
        let day = 86_400.0
        let now = Date()

        func expense(_ id: String, _ cents: Int, _ payer: String, _ note: String, _ daysAgo: Double) -> LedgerEntry {
            try! LedgerEntry.expense(
                id: id, ledgerId: ledgerId, amount: Money(cents: cents), paidBy: payer,
                splitRule: .equal, among: [Self.viewerId, Self.partnerId], note: note,
                date: now.addingTimeInterval(-daysAgo * day), createdBy: payer
            )
        }

        entries = [
            expense("1", 8420, Self.viewerId, "Groceries", 0),
            expense("2", 1250, Self.partnerId, "Coffee", 0),
            expense("3", 6600, Self.partnerId, "Dinner out", 1),
            expense("4", 2199, Self.viewerId, "Cat food", 3),
            LedgerEntry.settlement(
                id: "5", ledgerId: ledgerId, from: Self.viewerId, to: Self.partnerId,
                amount: Money(cents: 3000), note: "Venmo",
                date: now.addingTimeInterval(-4 * day), createdBy: Self.viewerId
            ),
            expense("6", 14000, Self.viewerId, "Flights", 6)
        ]
    }

    func ledger(for userId: String) async throws -> Ledger? {
        Ledger(id: "demo", memberIds: [Self.viewerId, Self.partnerId])
    }

    func users(ids: [String]) async throws -> [User] {
        [
            User(uid: Self.viewerId, displayName: "Josiah", email: "you@example.com",
                 groupIds: [], createdAt: .init(), lastActive: .init()),
            User(uid: Self.partnerId, displayName: "Laura", email: "them@example.com",
                 groupIds: [], createdAt: .init(), lastActive: .init())
        ]
    }

    func recordName(_ name: String, for userId: String, in ledgerId: String) async throws {}

    private var storedTemplates: [Template] = [
        Template(
            id: "monthly", ledgerId: "demo", name: "Monthly bills",
            lines: [
                TemplateLine(note: "Rent", amount: Money(cents: 180_000),
                             payer: .member(DemoLedgerSource.viewerId),
                             split: .percentage([DemoLedgerSource.viewerId: 60,
                                                 DemoLedgerSource.partnerId: 40])),
                TemplateLine(note: "Internet", amount: Money(cents: 7500)),
                TemplateLine(note: "Power", amount: Money(cents: 4200))
            ],
            createdBy: DemoLedgerSource.viewerId
        )
    ]

    func templates(in ledgerId: String) -> AsyncThrowingStream<[Template], Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(storedTemplates)
            continuation.finish()
        }
    }

    func save(_ template: Template) async throws {
        storedTemplates.removeAll { $0.id == template.id }
        storedTemplates.append(template)
    }

    func deleteTemplate(id: String, from ledgerId: String) async throws {
        storedTemplates.removeAll { $0.id == id }
    }

    func entries(in ledgerId: String) -> AsyncThrowingStream<[LedgerEntry], Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(entries)
            continuation.onTermination = { [weak self] _ in self?.continuations[id] = nil }
        }
    }

    func save(_ entry: LedgerEntry) async throws {
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
        for continuation in continuations.values { continuation.yield(entries) }
    }

    func delete(entryId: String, from ledgerId: String) async throws {
        entries.removeAll { $0.id == entryId }
        for continuation in continuations.values { continuation.yield(entries) }
    }

    /// Whether this launch should show the demo instead of signing in.
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-demoLedger")
    }
}

#Preview {
    LedgerScreen(
        store: LedgerStore(source: DemoLedgerSource(), viewerId: DemoLedgerSource.viewerId)
    )
}
#endif
