//
//  ManageGroup.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-06-08.
// Manage an individual group's settings
// Users? Public vs private? Archive? 

import SwiftUI
import SwiftData

struct ManageGroup: View {
    @AppStorage("userID") var userID: String = ""
    var group: Group
    
    @Environment(\.modelContext) var context
    
    var totalUnpaidExpense: Double {
        // find all expesnes that haven't been marked as complete, and sum their cost
        var totalGroupSpent = 0.0
        for expense in group.unwrappedExpenses {
            totalGroupSpent = totalGroupSpent + expense.amount
        }
        
        return totalGroupSpent
    }

    var body: some View {
        // List members
        // delete members
        // add members
        ForEach(group.unwrappedMembers) { member in
            HStack {
                Text(member.name ?? "Nothin")
            }
        }
        // don't list expenses
        //
    }
}
