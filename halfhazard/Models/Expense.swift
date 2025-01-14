//
//  Expense.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-13.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct Expense: Codable {
    let id: String
    var amount: Double
    let description: String?
    let groupId: String
    var createdBy: String
    let createdAt: Timestamp
    var splitType: SplitType
    var splits: [String: Double]
}

