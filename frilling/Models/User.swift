//
//  User.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-24.
//
// Should add UUIDs


import Foundation
import SwiftData

@Model
class User {
    let id = UUID()
    var name: String
    var groups: [Group]? // users won't necessarily have groups
    var expenses: [Expense] // new users won't have any expenses
    
    init(name: String, groups: [Group], expenses: [Expense]) {
        self.name = name
        self.groups = groups
        self.expenses = expenses
    }
}

