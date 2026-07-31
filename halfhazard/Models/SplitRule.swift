//
//  SplitRule.swift
//  halfhazard
//

import Foundation

/// How an expense divides among the people who share it.
///
/// This describes intent, not amounts. The amounts owed are always derived from the
/// rule by `SplitAllocator` and stored on the entry; the rule is kept so the edit
/// screen can show what you meant rather than reverse-engineering it from dollars.
///
/// Replaces the old `SplitType`, whose `currentUserOwes` / `currentUserOwed` cases
/// meant "relative to whoever created this", so they read backwards for the other person.
/// Who paid is now recorded explicitly on the entry instead of implied by the split.
enum SplitRule: Hashable {
    /// Divided evenly among the participants.
    case equal
    /// Percentages keyed by user id. Must sum to 100.
    case percentage([String: Double])
    /// Exact amounts keyed by user id. Must sum to the total.
    case exact([String: Money])
    /// Relative weights keyed by user id, e.g. 2:1. Must be positive.
    case shares([String: Int])
}

enum SplitError: LocalizedError, Equatable {
    case noParticipants
    case negativeTotal
    case percentagesMustSumTo100(actual: Double)
    case exactAmountsMustSumToTotal(actual: Money, expected: Money)
    case sharesMustBePositive
    case unknownParticipant(String)

    var errorDescription: String? {
        switch self {
        case .noParticipants:
            return "An expense needs at least one person to split between."
        case .negativeTotal:
            return "An expense cannot be a negative amount."
        case .percentagesMustSumTo100(let actual):
            return String(format: "Percentages add up to %.2f%%, not 100%%.", actual)
        case .exactAmountsMustSumToTotal(let actual, let expected):
            return "Amounts add up to \(actual.formatted()), not \(expected.formatted())."
        case .sharesMustBePositive:
            return "Every share must be greater than zero."
        case .unknownParticipant(let id):
            return "Split refers to somebody who isn't on this expense (\(id))."
        }
    }
}

/// Turns a total plus a rule into exact per-person amounts.
///
/// Every path routes through `distribute`, which uses the largest-remainder method so
/// the parts always sum back to the total to the cent. A 3-way split of $10.00 yields
/// 3.34 / 3.33 / 3.33 rather than three 3.33s that lose a penny.
enum SplitAllocator {
    static func allocate(
        total: Money,
        rule: SplitRule,
        among participants: [String]
    ) throws -> [String: Money] {
        guard !participants.isEmpty else { throw SplitError.noParticipants }
        guard total.cents >= 0 else { throw SplitError.negativeTotal }

        switch rule {
        case .equal:
            return distribute(total, weights: participants.map { ($0, 1.0) })

        case .percentage(let percentages):
            try validateKeys(of: percentages, against: participants)
            let sum = percentages.values.reduce(0, +)
            guard abs(sum - 100.0) < 0.01 else {
                throw SplitError.percentagesMustSumTo100(actual: sum)
            }
            return distribute(total, weights: participants.map { ($0, percentages[$0] ?? 0) })

        case .exact(let amounts):
            try validateKeys(of: amounts, against: participants)
            let sum = amounts.values.total
            guard sum == total else {
                throw SplitError.exactAmountsMustSumToTotal(actual: sum, expected: total)
            }
            return participants.reduce(into: [:]) { result, id in
                result[id] = amounts[id] ?? .zero
            }

        case .shares(let shares):
            try validateKeys(of: shares, against: participants)
            guard shares.values.allSatisfy({ $0 > 0 }), !shares.isEmpty else {
                throw SplitError.sharesMustBePositive
            }
            return distribute(total, weights: participants.map { ($0, Double(shares[$0] ?? 0)) })
        }
    }

    private static func validateKeys<V>(
        of dictionary: [String: V],
        against participants: [String]
    ) throws {
        let known = Set(participants)
        if let stray = dictionary.keys.first(where: { !known.contains($0) }) {
            throw SplitError.unknownParticipant(stray)
        }
    }

    /// Splits `total` proportionally to `weights`, handing out leftover cents to the
    /// largest fractional parts. Ties break on user id so the result is deterministic.
    private static func distribute(
        _ total: Money,
        weights: [(id: String, weight: Double)]
    ) -> [String: Money] {
        let totalWeight = weights.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            // Degenerate input (all zero weights): fall back to an even division.
            return distribute(total, weights: weights.map { ($0.id, 1.0) })
        }

        var allocated: [String: Money] = [:]
        var remainders: [(id: String, fraction: Double)] = []
        var assigned = 0

        for (id, weight) in weights {
            let ideal = Double(total.cents) * weight / totalWeight
            let whole = ideal.rounded(.down)
            allocated[id] = Money(cents: Int(whole))
            remainders.append((id, ideal - whole))
            assigned += Int(whole)
        }

        let leftover = total.cents - assigned
        let order = remainders.sorted {
            $0.fraction == $1.fraction ? $0.id < $1.id : $0.fraction > $1.fraction
        }
        for index in 0..<max(0, leftover) {
            let id = order[index % order.count].id
            allocated[id] = (allocated[id] ?? .zero) + Money(cents: 1)
        }

        return allocated
    }
}

// MARK: - Codable

/// Hand-written so Firestore stores a flat, readable shape:
/// `{ "type": "percentage", "values": { "uid": 60 } }`
extension SplitRule: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, values
    }

    private enum RuleType: String, Codable {
        case equal, percentage, exact, shares
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(RuleType.self, forKey: .type) {
        case .equal:
            self = .equal
        case .percentage:
            self = .percentage(try container.decode([String: Double].self, forKey: .values))
        case .exact:
            self = .exact(try container.decode([String: Money].self, forKey: .values))
        case .shares:
            self = .shares(try container.decode([String: Int].self, forKey: .values))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .equal:
            try container.encode(RuleType.equal, forKey: .type)
        case .percentage(let values):
            try container.encode(RuleType.percentage, forKey: .type)
            try container.encode(values, forKey: .values)
        case .exact(let values):
            try container.encode(RuleType.exact, forKey: .type)
            try container.encode(values, forKey: .values)
        case .shares(let values):
            try container.encode(RuleType.shares, forKey: .type)
            try container.encode(values, forKey: .values)
        }
    }
}
