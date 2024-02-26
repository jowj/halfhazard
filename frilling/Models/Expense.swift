//
//  Expense.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-24.
//
// Should add UUIDs


import Foundation

class Expense: Identifiable {
    // A class that models all the metadata we might want attached to /an expense/.
    let id = UUID()
    var name: String
    var amount: Double
    var author: User?
    var group: Group?
    var status: String
    
    init(name: String, amount: Double, author: User? = nil, group: Group? = nil, status: String) {
        self.name = name
        self.amount = amount
        self.author = author
        self.group = group
        self.status = status
    }
}
