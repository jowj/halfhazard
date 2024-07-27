// This contains the *primary*, default view of the app.
//  ContentView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    @AppStorage("email") var email: String = ""
    @AppStorage("fullName") var fullName: String = ""
    @AppStorage("userID") var userID: String = ""
    
    @Binding var navigationPath: NavigationPath
    
    @State private var showCreate = false
    @State private var showCreateCategory = false
    @State private var showAccountDetails = false
    @State private var showManageGroups = false
    @State private var selectedGroup: userGroup?
    @State private var searchQuery = ""
    
    @Query private var items: [Expense]
    @Query private var users: [User]
    
    @Environment(\.modelContext) var context
    
    var filteredGroups: [userGroup] {
        let currentUser = currentUser(users: users, currentUserID: userID)
        return currentUser.groups ?? []
    }
    
    
    
    var body: some View {
        if userID.isEmpty {
            LoginView()
        } else {
            NavigationSplitView {
                List(filteredGroups, selection: $selectedGroup) { group in
                    NavigationLink(group.name, value: group)
                        .contextMenu {
                            NavigationLink(destination: ManageGroup(group: group)) {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                }
                .navigationTitle("Your finances are halfhazard")
                .searchable(text: $searchQuery, prompt: "Search for an expense")
            } detail: {
                NavigationStack(path: $navigationPath) {
                    Group {
                        if let activeGroup = selectedGroup {
                            GroupView(selectedGroup: activeGroup)
                        } else {
                            Text("Select a group")
                        }
                    }
                    // MARK: Toolbar
                    .toolbar {
                        ToolbarItemGroup {
                            NavigationLink(destination: CreateExpenseView()) {
                                Label("Add Item", systemImage: "plus")
                            }
                            NavigationLink(destination: CreateCategoryView()) {
                                Label("Manage Categories", systemImage: "ellipsis")
                            }
                            NavigationLink(destination: ManageGroupsView()) {
                                Label("Manage Groups", systemImage: "person.3.fill")
                            }
                            NavigationLink(destination: LoginView()) {
                                Label("Login", systemImage: "person")
                            }
                        }
                    }
                }
            }
        }
    }
}
