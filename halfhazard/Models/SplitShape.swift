//
//  SplitShape.swift
//  halfhazard
//

import Foundation

/// How an entry's split reads back as a choice the edit screen can offer.
///
/// Three options cover almost everything two people do, but not everything the ledger holds:
/// a 70/30 from a template, or an uneven exact split carried in by the migration. Recognising
/// those as `asRecorded` is what stops an edit — of the amount, or the note, or the date —
/// from quietly flattening the split to 50/50 on the way out.
///
/// Out here rather than inside the sheet because getting it wrong corrupts real numbers
/// silently, which is exactly the sort of thing that should have a test.
enum SplitShape: String, CaseIterable, Identifiable {
    case evenly = "Split evenly"
    case allPartner = "They owe it all"
    case allViewer = "I owe it all"
    case asRecorded = "As recorded"

    var id: String { rawValue }

    static func of(_ entry: LedgerEntry, viewer: String) -> SplitShape {
        let mine = entry.owedBy[viewer] ?? .zero
        let theirs = entry.owedBy.filter { $0.key != viewer }.values.total

        if mine == entry.amount, theirs.isZero { return .allViewer }
        if mine.isZero, theirs == entry.amount, !entry.amount.isZero { return .allPartner }

        let even = try? SplitAllocator.allocate(
            total: entry.amount,
            rule: .equal,
            among: entry.owedBy.keys.sorted()
        )
        return even == entry.owedBy ? .evenly : .asRecorded
    }
}
