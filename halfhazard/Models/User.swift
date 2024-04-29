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
class User: Identifiable {
    
    var userID: String = ""
    var name: String? = ""

    @Relationship(deleteRule: .nullify, inverse: \Group.members)
        // TODO: make sure you understand this default value, because i'm REALLY not sure I do.
        var groups: [Group]? = [Group]() // users won't necessarily have groups
    
    var expenses: [Expense]? = [Expense]() // new users won't have any expenses
        
    init(userID: String, name: String? = nil, groups: [Group]? = [Group](), expenses: [Expense]? = [Expense]()) {
        self.userID = userID
        self.name = name
        self.groups = groups
        self.expenses = expenses
    }
}

