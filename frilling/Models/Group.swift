//
//  Group.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-24.
//
// Should add UUIDs

import Foundation

class Group {
    let id = UUID()
    var name: String
    var expenses: [Expense]? // New groups might not have any expenses
    var members: [User]? // New groups may not have any users
    var picture: Any // This is a test anyway.
    
    init(name: String, expenses: [Expense], members: [User], picture: Any) {
        self.name = name
        self.expenses = expenses
        self.members = members
        self.picture = picture
    }
}
