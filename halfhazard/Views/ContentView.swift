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
            LoginView(navigationPath: $navigationPath)
        } else {
            NavigationSplitView {
                List(filteredGroups, selection: $selectedGroup) { group in
                    NavigationLink(group.name, value: group)
                        .contextMenu {
                            Button("Edit") {
                                selectedGroup = group
                                navigationPath.append(group)
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
                    .navigationDestination(for: userGroup.self) { group in
                        ManageGroup(navigationPath: $navigationPath, group: group)
                    }
                    .navigationDestination(for: CreateExpenseDestination.self) { _ in
                        CreateExpenseView(navigationPath: $navigationPath)
                    }
                    .navigationDestination(for: CreateCategoryDestination.self) { _ in
                        CreateCategoryView(navigationPath: $navigationPath)
                    }
                    .navigationDestination(for: ManageGroupsDestination.self) { _ in
                        ManageGroupsView(navigationPath: $navigationPath)
                    }
                    .navigationDestination(for: AccountDetailsDestination.self) { _ in
                        LoginView(navigationPath: $navigationPath)
                    }

                }
                .toolbar {
                    ToolbarItemGroup {
                        NavigationLink(value: CreateExpenseDestination()) {
                            Label("Add Item", systemImage: "plus")
                        }
                        NavigationLink(value: CreateCategoryDestination()) {
                            Label("Manage Categories", systemImage: "ellipsis")
                        }
                                                                                
                        NavigationLink(value: ManageGroupsDestination()) {
                            Label("Manage Groups", systemImage: "person.3.fill")
                        }
                        NavigationLink(value: AccountDetailsDestination()) {
                            Label("Login", systemImage: "person")
                        }
                    }
                }
            }
        }
    }
}

struct CreateExpenseDestination: Hashable {}
struct CreateCategoryDestination: Hashable {}
struct ManageGroupsDestination: Hashable {}
struct AccountDetailsDestination: Hashable {}
