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
    
    // Custom coding keys to support optional fields
    enum CodingKeys: String, CodingKey {
        case id, name, memberIds, createdBy, createdAt, settings, settled, settledAt
    }
    
    // Custom decoder init to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        memberIds = try container.decode([String].self, forKey: .memberIds)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        createdAt = try container.decode(Timestamp.self, forKey: .createdAt)
        settings = try container.decode(Settings.self, forKey: .settings)
        
        // Handle optional "settled" field with default value
        settled = try container.decodeIfPresent(Bool.self, forKey: .settled) ?? false
        settledAt = try container.decodeIfPresent(Timestamp.self, forKey: .settledAt)
    }
    
    // Regular init for creating groups in code
    init(id: String, name: String, memberIds: [String], createdBy: String, 
         createdAt: Timestamp, settings: Settings, settled: Bool = false, settledAt: Timestamp? = nil) {
        self.id = id
        self.name = name
        self.memberIds = memberIds
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.settings = settings
        self.settled = settled
        self.settledAt = settledAt
    }
}
