// This contains the *primary*, default view of the app.
//  ContentView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI
import SwiftData

struct HomeView: View {

    @AppStorage("userID") var userID: String = ""

    @State private var showCreate = false
    @State private var showCreateCategory = false
    @State private var showAccountDetails = false
    @State private var showManageGroups = false
    @State private var expenseEdit: Expense?
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
    
    var body: some View {
        NavigationView {
            GroupView()
//            List {
//                // This ForEach shows each Expense and some buttons.
//                ForEach(filteredExpenses) { item in
//                    HStack {
//                        ExpenseView(expense: item)
//                            .contextMenu {
//                                Button(role: .destructive) {
//                                    withAnimation {
//                                        context.delete(item)
//                                        
//                                    }
//                                } label: {
//                                    Label("Delete", systemImage: "trash")
//                                        .symbolVariant(.circle.fill)
//                                }
//                                .tint(.orange)
//                                
//                                Button(role: .cancel) {
//                                    withAnimation {
//                                        expenseEdit = item
//                                    }
//                                } label: {
//                                    Label("Edit", systemImage: "pencil")
//                                        .symbolVariant(.circle.fill)
//                                }
//                                
//                                Button(role: .none) {
//                                    withAnimation {
//                                        item.isCompleted.toggle()
//                                    }
//                                } label: {
//                                    Label("Mark complete", systemImage: "checkmark")
//                                        .symbolVariant(.circle.fill)
//                                        .foregroundStyle(item.isCompleted ? .green :
//                                                .gray)
//                                }
//                            }
//                    }
//                }
//      
//            }
                .navigationTitle("Your finances are halfhazard")
                .searchable(text: $searchQuery,
                            prompt: "Search for an expense")
                .overlay {
                    if filteredExpenses.isEmpty {
                        ContentUnavailableView.search // this is, quite nice.
                    }
                } // This Tool bar section configures just the tool bar buttons
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
            
                .sheet(item: $expenseEdit) {
                    expenseEdit = nil
                } content: {item in
                    EditExpenseView(item: item)
#if os(macOS)
.frame(minWidth: 800, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .center)
#endif

            }
        }
    }
}

private extension HomeView {
    
}

#Preview {
    ContentView()
}

