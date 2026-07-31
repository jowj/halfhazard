//
//  Money.swift
//  halfhazard
//

import Foundation

/// A currency amount stored as integer minor units so splits always reconcile.
///
/// Doubles cannot represent most cent values exactly, which lets a split drift away
/// from its total. Every amount in the ledger is an exact whole number of cents.
struct Money: Hashable, Comparable, Codable, CustomStringConvertible {
    var cents: Int

    init(cents: Int) {
        self.cents = cents
    }

    /// Converts a floating-point amount. Only for migrating legacy `Double` data.
    ///
    /// This is lossy by nature and cannot be made exact: 1.005 is held as
    /// 1.00499999999999989, so it rounds to 100c rather than 101c. Use
    /// `init(decimalDollars:)` or `init(parsingDollars:)` for anything a person typed.
    init(roundingDollars dollars: Double) {
        self.cents = Int((dollars * 100).rounded())
    }

    /// Converts an exact decimal amount. This is the path user input should take.
    init(decimalDollars dollars: Decimal) {
        var scaled = dollars * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        self.cents = NSDecimalNumber(decimal: rounded).intValue
    }

    /// Parses typed input such as "84.20" without ever going through a Double.
    init?(parsingDollars text: String, locale: Locale = .current) {
        let separator = locale.decimalSeparator ?? "."
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let isNegative = trimmed.hasPrefix("-")

        var digits = trimmed.filter { $0.isNumber || String($0) == separator }
        guard !digits.isEmpty else { return nil }
        if separator != "." {
            digits = digits.replacingOccurrences(of: separator, with: ".")
        }
        guard digits.filter({ $0 == "." }).count <= 1 else { return nil }
        guard let value = Decimal(string: digits, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        self.init(decimalDollars: isNegative ? -value : value)
    }

    static let zero = Money(cents: 0)

    var dollars: Double { Double(cents) / 100 }
    var isZero: Bool { cents == 0 }
    var isNegative: Bool { cents < 0 }
    var magnitude: Money { Money(cents: abs(cents)) }

    static func + (lhs: Money, rhs: Money) -> Money { Money(cents: lhs.cents + rhs.cents) }
    static func - (lhs: Money, rhs: Money) -> Money { Money(cents: lhs.cents - rhs.cents) }
    static prefix func - (value: Money) -> Money { Money(cents: -value.cents) }
    static func += (lhs: inout Money, rhs: Money) { lhs = lhs + rhs }
    static func -= (lhs: inout Money, rhs: Money) { lhs = lhs - rhs }
    static func < (lhs: Money, rhs: Money) -> Bool { lhs.cents < rhs.cents }

    // Encoded as a bare integer so Firestore documents stay readable and
    // security rules can compare amounts numerically.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.cents = try container.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(cents)
    }

    /// Formats via Decimal rather than Double so the displayed value is exact.
    func formatted(currencyCode: String? = nil) -> String {
        let code = currencyCode ?? Locale.current.currency?.identifier ?? "USD"
        let value = Decimal(cents) / 100
        return value.formatted(.currency(code: code))
    }

    var description: String { formatted() }
}

extension Sequence where Element == Money {
    var total: Money { Money(cents: reduce(0) { $0 + $1.cents }) }
}
