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
    
    var body: some View {
        List {
            // This ForEach shows each Expense and some buttons.
            ForEach(filteredGroups) { item in
                Text(item.name)
                    .foregroundColor(.primary)
                    .font(.headline)
            }
        }
    }
}
