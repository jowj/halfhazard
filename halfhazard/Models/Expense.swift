//
//  Expense.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-13.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct Expense: Codable, Identifiable, Hashable {
    let id: String
    var amount: Double
    var description: String?
    let groupId: String
    var createdBy: String
    let createdAt: Timestamp
    var splitType: SplitType
    var splits: [String: Double]
    var settled: Bool = false
    var settledAt: Timestamp?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Expense, rhs: Expense) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Custom coding keys to support optional fields
    enum CodingKeys: String, CodingKey {
        case id, amount, description, groupId, createdBy, createdAt, splitType, splits, settled, settledAt
    }
    
    // Custom decoder init to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        amount = try container.decode(Double.self, forKey: .amount)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        groupId = try container.decode(String.self, forKey: .groupId)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        createdAt = try container.decode(Timestamp.self, forKey: .createdAt)
        
        // Handle split type - default to .equal if missing
        if let splitTypeString = try container.decodeIfPresent(String.self, forKey: .splitType) {
            splitType = SplitType(rawValue: splitTypeString) ?? .equal
        } else {
            splitType = .equal
        }
        
        // Handle splits with default empty dictionary
        splits = try container.decodeIfPresent([String: Double].self, forKey: .splits) ?? [:]
        
        // Handle optional "settled" field with default value
        settled = try container.decodeIfPresent(Bool.self, forKey: .settled) ?? false
        settledAt = try container.decodeIfPresent(Timestamp.self, forKey: .settledAt)
    }
    
    // Regular init for creating expenses in code
    init(id: String, amount: Double, description: String? = nil, groupId: String, 
         createdBy: String, createdAt: Timestamp, splitType: SplitType = .equal,
         splits: [String: Double], settled: Bool = false, settledAt: Timestamp? = nil) {
        self.id = id
        self.amount = amount
        self.description = description
        self.groupId = groupId
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.splitType = splitType
        self.splits = splits
        self.settled = settled
        self.settledAt = settledAt
    }
}

