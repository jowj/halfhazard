//
//  Group.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-02-24.
//
// Should add UUIDs

import Foundation
import SwiftData

@Model
class Group {
    
    var name: String = ""
    var expenses: [Expense]? = [Expense]() // New groups might not have any expenses
    var members: [User]? = [User]() // New groups may not have any users
    
    var unwrappedExpenses: [Expense] {
        let unwrappedExpenses = [Expense]()
        if let unwrappedExpenses = expenses {
            return unwrappedExpenses
        }
        return unwrappedExpenses
    }
    
    init(name: String, expenses: [Expense]? = [Expense](), members: [User]? = [User]()) {
        self.name = name
        self.expenses = expenses
        self.members = members
    }
}
