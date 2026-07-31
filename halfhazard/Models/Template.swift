//
//  Template.swift
//  halfhazard
//

import Foundation

/// Who fronts the money for a template line.
///
/// A template describes a recurring shape — "rent, split 60/40, on Josiah's card" — and who
/// pays is part of that shape. It is stated as a role rather than baked into whoever happened
/// to write the template, because a template is applied by either person.
enum TemplatePayer: Hashable {
    /// Always this person, whoever applies the template.
    case member(String)
    /// Whoever is applying it.
    case applier

    func resolve(applier: String) -> String {
        switch self {
        case .member(let id): return id
        case .applier: return applier
        }
    }
}

/// One expense in a template.
struct TemplateLine: Identifiable, Hashable, Codable {
    let id: String
    var note: String
    var amount: Money
    var category: String?
    var payer: TemplatePayer
    /// Keyed by user id, like every other split in the app.
    var split: SplitRule

    init(
        id: String = UUID().uuidString,
        note: String,
        amount: Money,
        category: String? = nil,
        payer: TemplatePayer = .applier,
        split: SplitRule = .equal
    ) {
        self.id = id
        self.note = note
        self.amount = amount
        self.category = category
        self.payer = payer
        self.split = split
    }
}

/// A set of expenses written once and applied whenever they recur.
///
/// The old `TemplateItem.createExpense` mapped custom percentages onto members **by array
/// index**: it took `Array(percentages.keys)` — arbitrary order, since it is a dictionary —
/// and zipped it against the member list, so who got which percentage was luck, and could
/// differ between two runs of the same template. Splits here are `SplitRule`s keyed by user
/// id, the same as everywhere else, so there is no mapping step to get wrong. A rule naming
/// somebody who is not on the ledger fails loudly in `SplitAllocator` rather than quietly
/// allocating to the wrong person.
struct Template: Identifiable, Hashable, Codable {
    let id: String
    let ledgerId: String
    var name: String
    var lines: [TemplateLine]
    let createdBy: String
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        ledgerId: String,
        name: String,
        lines: [TemplateLine] = [],
        createdBy: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ledgerId = ledgerId
        self.name = name
        self.lines = lines
        self.createdBy = createdBy
        self.createdAt = createdAt
    }

    var total: Money { lines.map(\.amount).total }

    /// Turns the template into real entries.
    ///
    /// Nothing is written here; the caller decides. Throws rather than guessing if a line's
    /// split refers to somebody outside the ledger, which is how a template outlives a change
    /// in who is on it.
    func entries(
        appliedBy applier: String,
        among members: [String],
        date: Date = Date(),
        createdAt: Date = Date(),
        id makeId: (TemplateLine) -> String = { _ in UUID().uuidString }
    ) throws -> [LedgerEntry] {
        try lines.map { line in
            try LedgerEntry.expense(
                id: makeId(line),
                ledgerId: ledgerId,
                amount: line.amount,
                paidBy: line.payer.resolve(applier: applier),
                splitRule: line.split,
                among: members,
                note: line.note.isEmpty ? nil : line.note,
                category: line.category,
                date: date,
                createdAt: createdAt,
                createdBy: applier
            )
        }
    }
}

// MARK: - Codable

/// Hand-written so Firestore holds a flat, readable shape:
/// `{ "kind": "member", "id": "…" }` or `{ "kind": "applier" }`.
extension TemplatePayer: Codable {
    private enum CodingKeys: String, CodingKey { case kind, id }
    private enum Kind: String, Codable { case member, applier }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .member:
            self = .member(try container.decode(String.self, forKey: .id))
        case .applier:
            self = .applier
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .member(let id):
            try container.encode(Kind.member, forKey: .kind)
            try container.encode(id, forKey: .id)
        case .applier:
            try container.encode(Kind.applier, forKey: .kind)
        }
    }
}
