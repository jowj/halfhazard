//
//  Expense.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import Foundation

class Expense {
    // A class that models all the metadata we might want attached to /an expense/.
    var name: String
    var amount: Double
    var author: User
    var group: Group?
    var status: String
    
    init(name: String, amount: Double, author: User, group: Group, status: String) {
        self.name = name
        self.amount = amount
        self.author = author
        self.group = group
        self.status = status
    }
}
