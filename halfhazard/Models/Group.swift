//
//  Group.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-13.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct Group: Codable, Identifiable, Hashable, Equatable {
    static func == (lhs: Group, rhs: Group) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    let id: String
    var name: String
    var memberIds: [String]
    var createdBy: String // userid
    let createdAt: Timestamp
    var settings: Settings
    var settled: Bool = false
    var settledAt: Timestamp?
}
