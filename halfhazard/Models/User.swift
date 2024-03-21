//
//  User.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-02-24.
//
// Should add UUIDs


import Foundation
import SwiftData

@Model
class User: Identifiable{
    let id: String
    let emailAddress: String
    var fullName: String
    var groups: [Group]? // users won't necessarily have groups
    var expenses: [Expense]? // new users won't have any expenses
    
    init(id: String, emailAddress: String, fullName: String, groups: [Group]?, expenses: [Expense]?) {
        self.id = id
        self.emailAddress = emailAddress
        self.fullName = fullName
        self.groups = groups
        self.expenses = expenses
    }
}

