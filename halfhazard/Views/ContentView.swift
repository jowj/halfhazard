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
    @State private var selectedGroup: Group?
    @State private var searchQuery = ""
    
    @Query private var items: [Expense]
    @Query private var users: [User]
    
    @Environment(\.modelContext) var context
    
    var filteredGroups: [Group] {
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
                            Button("Edit") {
                                selectedGroup = group
                                navigationPath.append(group)
                            }
                        }
                }
    
                .navigationTitle("Your finances are halfhazard")
                .searchable(text: $searchQuery,
                            prompt: "Search for an expense")
                // This Tool bar section configures just the tool bar buttons
#if os(iOS)
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            showCreate.toggle()
                        } label: {
                            Label("Add Item", systemImage: "plus")
                        }
                        
                        Button {
                            showCreateCategory.toggle()
                        } label: {
                            Label("Manage Categories", systemImage: "ellipsis")
                        }
                        
                        Button {
                            showManageGroups.toggle()
                        } label: {
                            Label("Manage Groups", systemImage: "person.3.fill")
                        }
                        Button {
                            showAccountDetails.toggle()
                        } label: {
                            Label("Login", systemImage: "person")
                        }
                    }
                
                    
                    
                }
#endif
 // THese .sheets are all related to the toolbar stuff above
                .sheet(isPresented: $showCreate,
                       content: {
                    NavigationStack {
                        CreateExpenseView()
    #if os(macOS)
                            .frame(minWidth: 800, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .center)
    #endif
                        
                    }
                    // stolen from https://stackoverflow.com/questions/66216468/how-to-make-a-swiftui-sheet-size-match-the-width-height-of-window-on-macos
                })
                .sheet(isPresented: $showCreateCategory,
                       content: {
                    NavigationStack {
                        CreateCategoryView()
    #if os(macOS)
                            .frame(minWidth: 800, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .center)
    #endif
                    }
                })
                .sheet(isPresented: $showManageGroups,
                       content: {
                    NavigationStack {
                        ManageGroupsView()
    #if os(macOS)
                            .frame(minWidth: 800, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .center)
    #endif
                        
                    }
                })
                .sheet(isPresented: $showAccountDetails,
                       content: {
                    NavigationStack {
                        LoginView()
    #if os(macOS)
                            .frame(minWidth: 800, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .center)
    #endif
                        
                    }
                })


            } detail: {
                NavigationStack(path: $navigationPath) {
                    if let activeGroup = selectedGroup {
                        GroupView(selectedGroup: activeGroup)
                            .navigationDestination(for: Group.self) { group in
                                ManageGroup(navigationPath: $navigationPath, group: group)
                            }
                    } else {
                        Text("Select a group")
                    }
                }
            }
#if os(macOS)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        showCreate.toggle()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    
                    Button {
                        showCreateCategory.toggle()
                    } label: {
                        Label("Manage Categories", systemImage: "ellipsis")
                    }
                    
                    Button {
                        showManageGroups.toggle()
                    } label: {
                        Label("Manage Groups", systemImage: "person.3.fill")
                    }
                    Button {
                        showAccountDetails.toggle()
                    } label: {
                        Label("Login", systemImage: "person")
                    }
                }
            }
#endif
        }
        
    }
    
}
