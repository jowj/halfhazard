//
//  GroupView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-04-14.
//

import SwiftUI
import SwiftData



struct GroupView: View {
    @AppStorage("userID") var userID: String = ""

    @State private var expenseEdit: Expense?
    @State private var searchQuery = ""
    @State private var selectedGroup: Group
    
    @Query private var items: [Group]
    @Query private var users: [User]
    
    @Environment(\.modelContext) var context
    
    var filteredGroups: [Group] {
        let currentUser = currentUser(users: users, currentUserID: userID)
        if let userGroups = currentUser.groups {
            return userGroups
        } else {
            return [Group]()
        }
    }
    
    var filteredExpense: [Expense]() {
        for expense in group {
            if expense.group?.name == group.name {
                filteredExpense.append(expense)
            }
        }
    }
    var body: some View {
        List {
            // This ForEach shows a group link and its child expenses.
            Text("GroupView is called")
            ForEach(filteredGroups) { group in
                // I might need to make a brand new view that's provides filtered expenses
                // Not sure how to organize that. My main view folder is getting pretty crowded.
                // Annoying.

                
                ForEach(filteredExpense) { expense in
                    NavigationLink(ExpenseView(expense: expense))

                }
                
            }
        }
    }
}
