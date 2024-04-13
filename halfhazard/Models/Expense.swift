//
//  Expense.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-02-24.
//
// Should add UUIDs


import Foundation
import SwiftData

@Model
class Expense: Identifiable {
    // A class that models all the metadata we might want attached to /an expense/.
    let expenseID = UUID()
    var name: String = ""
    var amount: Double = 0.0
    var isCompleted: Bool = false
    var timestamp: Date = Date.now
    
    @Relationship(deleteRule: .nullify, inverse: \User.expenses)
        var author: User? = nil
    @Relationship(deleteRule: .nullify, inverse: \Group.expenses)
        var group: Group? = nil
    @Relationship(deleteRule: .nullify, inverse: \ExpenseCategory.items)
        var category: ExpenseCategory? = nil
    
    var amountOwed: Double? {
        // I'll have to figure out a split percentage deal, too, but for now just focus on even splits.
        guard ((group?.members?.isEmpty) == nil) else { return nil }
        
        if let people = group?.members?.count {
            let evenSplit =  amount / Double(people)
            
            return evenSplit
        } else {
            return amount / 1
        }
        
    }
    init(name: String = "", amount: Double = 0.0) {
        self.name = name
        self.amount = amount
    }
}
