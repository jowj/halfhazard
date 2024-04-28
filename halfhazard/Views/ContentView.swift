// This contains the *primary*, default view of the app.
//  ContentView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    // you THINK you are re-initiatlizing variables, but because of how @AppStorage works you're not!
    // Anytime you want to ref an appstorage var you "reinit" just like this.
    @AppStorage("email") var email: String = ""
    @AppStorage("fullName") var fullName: String = ""
    @AppStorage("userID") var userID: String = ""
    
    var loggedIn = false
    
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
        // I *think* this has to be var, not let, because if its `let` then it can't get updated when the users .groups property is updated?
        // I think?
        if var userGroups = currentUser.groups {
            print("Found some groups: \(userGroups.count)")
            return userGroups
        } else {
            return [Group]()
        }
    }
    
    
    var body: some View {
        if userID.isEmpty {
            NavigationStack {
                LoginView()
            }
        } else {
//            LoginView()

            NavigationSplitView {
                
                List(filteredGroups, selection: $selectedGroup) { group in
                    // show me a list of all groups!
                    NavigationLink("\(group.name)", value: group)
                        //.toolbar(removing: .sidebarToggle)
                }
            } detail: {
                Text("Detail view worked!")
                // Show me all the expenses inside a group
                if let activeGroup = selectedGroup.self {
                    GroupView(selectedGroup: activeGroup)
                }
            }
            
            .navigationTitle("Your finances are halfhazard")
            .searchable(text: $searchQuery,
                        prompt: "Search for an expense")
            // This Tool bar section configures just the tool bar buttons
            .toolbar {
                ToolbarItem {
                    Button {
                        showCreate.toggle()
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                    
                }
                ToolbarItem {
                    Button {
                        showCreateCategory.toggle()
                    } label: {
                        Label("Manage Categories", systemImage: "ellipsis")
                    }
                    
                }
                ToolbarItem {
                    Button {
                        showManageGroups.toggle()
                    } label: {
                        Label("Manage Groups", systemImage: "person.3.fill")
                    }
                }
                ToolbarItem {
                    Button {
                        showAccountDetails.toggle()
                    } label: {
                        Label("Login", systemImage: "person")
                    }
                    
                }
                
                
            } // THese .sheets are all related to the toolbar stuff above.
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
                
        }
        
    }
    
}
