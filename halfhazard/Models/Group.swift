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
    
    var name: String
    var expenses: [Expense]? // New groups might not have any expenses
    var members: [User]? // New groups may not have any users
    
    init(name: String) {
        self.name = name
    }
}
