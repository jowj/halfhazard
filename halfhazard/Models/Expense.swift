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
    let description: String?
    let groupId: String
    var createdBy: String
    let createdAt: Timestamp
    var splitType: SplitType
    var splits: [String: Double]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Expense, rhs: Expense) -> Bool {
        return lhs.id == rhs.id
    }
}

