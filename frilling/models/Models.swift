//
//  Models.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import Foundation

class Group {
    var name: String
    var expenses: [Expense]
    var members: [User]
    var picture: Any
    
    init(name: String, expenses: [Expense], members: [User], picture: Any) {
        self.name = name
        self.expenses = expenses
        self.members = members
        self.picture = picture
    }
}


class Expense {
    // A class that models all the metadata we might want attached to /an expense/.
    var name: String
    var amount: Double
    var author: User
    var group: Group
    var status: String
    
    init(name: String, amount: Double, author: User, group: Group, status: String) {
        self.name = name
        self.amount = amount
        self.author = author
        self.group = group
        self.status = status
    }
}

class User {
    var name: String
    var groups: [Group]
    var expenses: [Expense]
    
    init(name: String, groups: [Group], expenses: [Expense]) {
        self.name = name
        self.groups = groups
        self.expenses = expenses
    }
}

