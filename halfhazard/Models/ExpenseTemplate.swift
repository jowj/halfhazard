//
//  ExpenseTemplate.swift
//  halfhazard
//
//  Created by Claude on 2025-07-20.
//

import Foundation
import FirebaseFirestore

/// Represents a user-created template containing multiple expense items
struct ExpenseTemplate: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String?
    let createdBy: String // user ID
    let createdAt: Timestamp
    let templateItems: [TemplateItem]
    let isShared: Bool // whether other users can see/use this template
    
    // Coding keys for Firestore
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdBy
        case createdAt
        case templateItems
        case isShared
    }
    
    init(id: String = UUID().uuidString, 
         name: String, 
         description: String? = nil, 
         createdBy: String, 
         createdAt: Timestamp = Timestamp(), 
         templateItems: [TemplateItem] = [], 
         isShared: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.templateItems = templateItems
        self.isShared = isShared
    }
    
    /// Calculate the total amount of all items in the template
    var totalAmount: Double {
        return templateItems.reduce(0) { $0 + $1.amount }
    }
    
    /// Get a preview of the template (first few items)
    func getPreview(limit: Int = 3) -> [TemplateItem] {
        return Array(templateItems.prefix(limit))
    }
}

/// Represents an individual expense item within a template
struct TemplateItem: Identifiable, Codable, Hashable {
    let id: String
    let amount: Double
    let description: String
    let splitType: SplitType
    let customSplitPercentages: [String: Double]? // percentage splits for custom type
    let category: String? // optional categorization
    
    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case description
        case splitType
        case customSplitPercentages
        case category
    }
    
    init(id: String = UUID().uuidString,
         amount: Double,
         description: String,
         splitType: SplitType = .equal,
         customSplitPercentages: [String: Double]? = nil,
         category: String? = nil) {
        self.id = id
        self.amount = amount
        self.description = description
        self.splitType = splitType
        self.customSplitPercentages = customSplitPercentages
        self.category = category
    }
    
    /// Validate that custom split percentages sum to 100%
    func validateCustomSplits() -> Bool {
        guard splitType == .custom, let percentages = customSplitPercentages else {
            return true // Not custom split, so no validation needed
        }
        
        let total = percentages.values.reduce(0, +)
        return abs(total - 100.0) < 0.01 // Allow for small floating point errors
    }
    
    /// Convert this template item to a real expense for a specific group
    func createExpense(forGroup groupId: String, 
                      createdBy userId: String, 
                      groupMembers: [String]) -> Expense {
        var splits: [String: Double] = [:]
        
        switch splitType {
        case .equal:
            let splitAmount = amount / Double(groupMembers.count)
            for memberId in groupMembers {
                splits[memberId] = splitAmount
            }
            
        case .currentUserOwes:
            splits[userId] = amount

        case .currentUserOwed:
            // Current user paid and is owed - other members split the amount equally
            let otherMembers = groupMembers.filter { $0 != userId }

            if otherMembers.isEmpty {
                // Edge case: Current user is the only member
                splits[userId] = 0
            } else {
                // Other members split the amount equally, current user gets 0
                let splitAmount = amount / Double(otherMembers.count)
                for memberId in otherMembers {
                    splits[memberId] = splitAmount
                }
                splits[userId] = 0
            }
            
        case .custom:
            if let percentages = customSplitPercentages {
                // Map percentage roles to actual group members
                // For now, we'll use a simple mapping approach
                let memberCount = groupMembers.count
                let percentageKeys = Array(percentages.keys)
                
                for (index, memberId) in groupMembers.enumerated() {
                    if index < percentageKeys.count {
                        let percentage = percentages[percentageKeys[index]] ?? 0
                        splits[memberId] = amount * (percentage / 100.0)
                    } else {
                        // If more members than percentages, distribute remaining equally
                        splits[memberId] = 0
                    }
                }
            } else {
                // Fallback to equal split if custom percentages are missing
                let splitAmount = amount / Double(groupMembers.count)
                for memberId in groupMembers {
                    splits[memberId] = splitAmount
                }
            }
        }
        
        return Expense(
            id: UUID().uuidString,
            amount: amount,
            description: description,
            groupId: groupId,
            createdBy: userId,
            createdAt: Timestamp(),
            splitType: splitType,
            splits: splits,
            customSplitPercentages: customSplitPercentages
        )
    }
}