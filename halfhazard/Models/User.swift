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
    
    let id: String
    var name: String?

    @Relationship(deleteRule: .nullify, inverse: \Group.members) var groups: [Group]? // users won't necessarily have groups
    var expenses: [Expense]? // new users won't have any expenses
        
    init(id: String) {
        self.id = id
    }
}

