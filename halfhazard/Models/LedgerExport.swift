//
//  LedgerExport.swift
//  halfhazard
//

import Foundation

/// Reading and writing the ledger as a file.
///
/// Two formats, on purpose:
///
/// - **JSON** is the ledger's own shape. It round-trips exactly — ids, split rules, the lot —
///   so it is the one to use for a backup, or for moving a ledger somewhere else.
/// - **CSV** is for a spreadsheet, and is lossy by nature: it names people rather than
///   identifying them, and it records what each person owed rather than the rule that
///   produced it. Importing one rebuilds entries from the amounts, which is faithful to the
///   money but not to the intent.
///
/// Everything here is pure. Parsing reports what it could not read rather than throwing the
/// whole file away, because a single bad row in a hundred should not cost the other
/// ninety-nine.
enum LedgerExport {

    // MARK: - Writing

    static func json(_ entries: [LedgerEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries.sorted { $0.date < $1.date })
    }

    /// One row per entry, with a paid and an owed column for each person.
    ///
    /// Columns are named after people, since a spreadsheet is for reading. The ids are kept
    /// in a trailing column so a file that goes out and comes back can still identify who is
    /// who when a name has changed in between.
    static func csv(_ entries: [LedgerEntry], members: [String], name: (String) -> String) -> String {
        let people = members.sorted()
        var header = ["date", "kind", "description", "category", "amount"]
        header += people.map { "paid_\(name($0))" }
        header += people.map { "owed_\(name($0))" }
        header += ["id", "member_ids"]

        var rows = [header.map(escape).joined(separator: ",")]

        for entry in entries.sorted(by: { $0.date < $1.date }) {
            var row = [
                Self.dateFormatter.string(from: entry.date),
                entry.kind.rawValue,
                entry.note ?? "",
                entry.category ?? "",
                dollars(entry.amount)
            ]
            row += people.map { dollars(entry.paidBy[$0] ?? .zero) }
            row += people.map { dollars(entry.owedBy[$0] ?? .zero) }
            row += [entry.id, people.joined(separator: " ")]
            rows.append(row.map(escape).joined(separator: ","))
        }

        return rows.joined(separator: "\n")
    }

    // MARK: - Reading

    /// What a file turned into, and everything about it that could not be read.
    struct ImportResult {
        var entries: [LedgerEntry] = []
        var issues: [Issue] = []

        struct Issue: Hashable {
            /// 1-based, counting the header, so it matches what a spreadsheet shows.
            let row: Int
            let message: String
        }

        var isEmpty: Bool { entries.isEmpty }
    }

    static func fromJSON(
        _ data: Data,
        ledgerId: String,
        members: [String],
        importedBy: String
    ) -> ImportResult {
        var result = ImportResult()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let decoded = try? decoder.decode([LedgerEntry].self, from: data) else {
            result.issues.append(.init(row: 0, message: "This is not a ledger export."))
            return result
        }

        let known = Set(members)
        for (index, entry) in decoded.enumerated() {
            let strangers = entry.participants.subtracting(known).sorted()
            guard strangers.isEmpty else {
                result.issues.append(.init(
                    row: index + 1,
                    message: "\(entry.note ?? entry.id): refers to somebody not on this ledger (\(strangers.joined(separator: ", ")))"
                ))
                continue
            }
            guard entry.isBalanced else {
                result.issues.append(.init(
                    row: index + 1,
                    message: "\(entry.note ?? entry.id): paid and owed do not both add up to \(entry.amount.formatted())"
                ))
                continue
            }

            // Rebuilt onto this ledger, so a file exported from elsewhere lands in the right
            // place. `ledgerId` stays a `let` on the entry: it is not something to edit in
            // passing, only to state when one is made.
            result.entries.append(LedgerEntry(
                id: entry.id,
                ledgerId: ledgerId,
                kind: entry.kind,
                amount: entry.amount,
                paidBy: entry.paidBy,
                owedBy: entry.owedBy,
                note: entry.note,
                category: entry.category,
                splitRule: entry.splitRule,
                date: entry.date,
                createdAt: entry.createdAt,
                createdBy: entry.createdBy
            ))
        }
        return result
    }

    static func fromCSV(
        _ text: String,
        ledgerId: String,
        members: [String],
        importedBy: String,
        name: (String) -> String,
        makeId: () -> String = { UUID().uuidString }
    ) -> ImportResult {
        var result = ImportResult()
        let lines = text.components(separatedBy: .newlines).filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard lines.count > 1 else {
            result.issues.append(.init(row: 0, message: "The file has no rows."))
            return result
        }

        let header = parseRow(lines[0]).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        func column(_ named: String) -> Int? { header.firstIndex(of: named) }

        guard let amountColumn = column("amount") else {
            result.issues.append(.init(row: 1, message: "No `amount` column."))
            return result
        }

        // Columns are named after people; map each back to a user id, by name and by id, so a
        // file still imports after somebody has changed their display name.
        var paidColumn: [Int: String] = [:]
        var owedColumn: [Int: String] = [:]
        for member in members {
            let label = name(member).lowercased()
            for (index, title) in header.enumerated() {
                if title == "paid_\(label)" || title == "paid_\(member.lowercased())" {
                    paidColumn[index] = member
                }
                if title == "owed_\(label)" || title == "owed_\(member.lowercased())" {
                    owedColumn[index] = member
                }
            }
        }

        if paidColumn.isEmpty || owedColumn.isEmpty {
            result.issues.append(.init(
                row: 1,
                message: "No paid_/owed_ columns matching the people on this ledger."
            ))
            return result
        }

        for (offset, line) in lines.dropFirst().enumerated() {
            let row = offset + 2
            let values = parseRow(line)
            func value(_ index: Int?) -> String {
                guard let index, index < values.count else { return "" }
                return values[index].trimmingCharacters(in: .whitespaces)
            }

            guard let amount = Money(parsingDollars: value(amountColumn)), amount.cents > 0 else {
                result.issues.append(.init(row: row, message: "Amount is missing or not a number."))
                continue
            }

            var paidBy: [String: Money] = [:]
            for (index, member) in paidColumn {
                if let money = Money(parsingDollars: value(index)), !money.isZero { paidBy[member] = money }
            }
            var owedBy: [String: Money] = [:]
            for (index, member) in owedColumn {
                if let money = Money(parsingDollars: value(index)), !money.isZero { owedBy[member] = money }
            }

            guard paidBy.values.total == amount else {
                result.issues.append(.init(
                    row: row,
                    message: "The paid columns add up to \(paidBy.values.total.formatted()), not \(amount.formatted())."
                ))
                continue
            }
            guard owedBy.values.total == amount else {
                result.issues.append(.init(
                    row: row,
                    message: "The owed columns add up to \(owedBy.values.total.formatted()), not \(amount.formatted())."
                ))
                continue
            }

            let kind: EntryKind = value(column("kind")) == EntryKind.settlement.rawValue ? .settlement : .expense
            let date = Self.dateFormatter.date(from: value(column("date")))
                ?? Self.looseDate(value(column("date")))
            let note = value(column("description"))
            let category = value(column("category"))
            let id = value(column("id"))

            result.entries.append(LedgerEntry(
                // An id carried in the file makes re-importing the same export idempotent
                // rather than doubling the ledger.
                id: id.isEmpty ? makeId() : id,
                ledgerId: ledgerId,
                kind: kind,
                amount: amount,
                paidBy: paidBy,
                owedBy: owedBy,
                note: note.isEmpty ? nil : note,
                category: category.isEmpty ? nil : category,
                // The rule that produced these amounts is not in the file. The amounts are.
                splitRule: kind == .settlement ? nil : .exact(owedBy),
                date: date ?? Date(),
                createdAt: Date(),
                createdBy: importedBy
            ))
        }

        if result.entries.isEmpty && result.issues.isEmpty {
            result.issues.append(.init(row: 0, message: "Nothing to import."))
        }
        return result
    }

    // MARK: - Plumbing

    static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    /// A hand-typed date, for a file somebody edited in a spreadsheet.
    private static func looseDate(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        for format in ["yyyy-MM-dd", "MM/dd/yyyy", "M/d/yy", "dd/MM/yyyy"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private static func dollars(_ money: Money) -> String {
        String(format: "%.2f", money.dollars)
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// Splits one CSV line, honouring quoted fields and doubled quotes inside them.
    static func parseRow(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var inQuotes = false
        var characters = Array(line)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if inQuotes, index + 1 < characters.count, characters[index + 1] == "\"" {
                    current.append("\"")
                    index += 1
                } else {
                    inQuotes.toggle()
                }
            } else if character == "," && !inQuotes {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
            index += 1
        }
        values.append(current)
        return values
    }
}
