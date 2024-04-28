// This contains the *primary*, default view of the app.
//  ContentView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI
import SwiftData

//TODO: I'm pretty sure this is redundant now?
struct HomeView: View {
    
    @AppStorage("userID") var userID: String = ""
    
    @State private var searchQuery = ""
    
    @Query private var items: [Expense]
    @Query private var users: [User]
    
    @Environment(\.modelContext) var context
    
    var filteredExpensesByUser: [Expense] {
        var filteredExpensesByUser = [Expense]()
        if userID.isEmpty {
            return filteredExpensesByUser
        } else {
            let currentUser = currentUser(users: users, currentUserID: userID)
            for expense in filteredExpenses {
                if expense.author?.userID == currentUser.userID {
                    filteredExpensesByUser.append(expense)
                }
            }
            return filteredExpensesByUser
        }
    }
    
    var filteredExpenses: [Expense] {
        if searchQuery.isEmpty {
            return items
        }
        
        let filteredExpenses = filteredExpensesByUser.compactMap { item in
            let titleContainsQuery = item.name.range(of: searchQuery, options:
                    .caseInsensitive) != nil
            
            let categoryTitleContainsQuery = item.category?.title.range(of: searchQuery, options:
                    .caseInsensitive) != nil
            
            // if either thing is true, return them, otherwise return nil
            return (titleContainsQuery || categoryTitleContainsQuery) ? item : nil
        }
        return filteredExpenses
    }
    
    var filteredGroups: [Group] {
        let currentUser = currentUser(users: users, currentUserID: userID)
        if let userGroups = currentUser.groups {
            return userGroups
        } else {
            return [Group]()
        }
    }
    
    var body: some View {
        List {
            //
            ForEach(filteredGroups) {group in
                NavigationLink {
                    GroupView(selectedGroup: group)
                } label: {
                    Text(group.name)
                }

            }
        }
    }
}

private extension HomeView {
    
}
