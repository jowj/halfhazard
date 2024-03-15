//
//  Expense.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-24.
//
// Should add UUIDs


import Foundation
import SwiftData

@Model
class Expense: Identifiable {
    // A class that models all the metadata we might want attached to /an expense/.
    let id = UUID()
    var name: String
    var amount: Double
    var author: User?
    var group: Group?
    var isCompleted: Bool
    var timestamp: Date
    
    
    @Relationship(deleteRule: .nullify, inverse: \ExpenseCategory.items) // this line differs from tutorials because the deleteRule label didn't used to be necessary.
    var category: ExpenseCategory?
    
    init(name: String = "",
         amount: Double = 0.0,
         author: User? = nil,
         group: Group? = nil,
         isCompleted: Bool = false,
         timestamp: Date = .now,
         category: ExpenseCategory? = nil
    ) {
        self.name = name
        self.amount = amount
        self.author = author
        self.group = group
        self.isCompleted = isCompleted
        self.timestamp = timestamp
    }
}
