//
//  Changelog.swift
//  halfhazard
//
//  Created by Claude on 2025-11-02.
//

import Foundation

struct ChangelogEntry: Codable, Identifiable {
    var id: String { hash }
    let hash: String
    let date: Date
    let message: String
    let author: String
}

struct Changelog: Codable {
    let generatedAt: Date
    let entries: [ChangelogEntry]
}
