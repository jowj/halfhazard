// This contains the *primary*, default view of the app.
//  ContentView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI
import SwiftData

struct HomeView: View {

    @State private var showCreate = false
    @State private var showCreateCategory = false
    @State private var showAccountDetails = false
    
    @State private var expenseEdit: Expense?
    @Query private var items: [Expense]
    
    @State private var searchQuery = ""
    
    @Environment(\.modelContext) var context
    
    var filteredExpenses: [Expense] {
        if searchQuery.isEmpty {
            return items
        }
        
        let filteredExpenses = items.compactMap { item in
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
        NavigationStack {
            List {
                ForEach(filteredExpenses) { item in
                    HStack {
                        ExpenseView(expense: item)

                        Spacer()
                        
                        Button(role: .destructive) {
                            withAnimation {
                                context.delete(item)
                                
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .symbolVariant(.circle.fill)
                        }
                        .tint(.orange)
                        
                        Button(role: .destructive) {
                            withAnimation {
                                expenseEdit = item
                            }
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .symbolVariant(.circle.fill)
                        }

                        Button {
                            withAnimation {
                                item.isCompleted.toggle()
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .symbolVariant(.circle.fill)
                                .foregroundStyle(item.isCompleted ? .green :
                                        .gray)
                        }
                    }
                }
      
            }
                .navigationTitle("Your finances are halfhazard")
                .searchable(text: $searchQuery,
                            prompt: "Search for an expense or expense category")
                .overlay {
                    if filteredExpenses.isEmpty {
                        ContentUnavailableView.search // this is, quite nice.
                    }
                }
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
                            showAccountDetails.toggle()
                        } label: {
                            Label("Login", systemImage: "person")
                        }
                        
                    }


                }
                .sheet(isPresented: $showCreate,
                       content: {
                    NavigationStack {
                        CreateExpenseView().frame(minWidth: 800, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .center)
                    }
                    // stolen from https://stackoverflow.com/questions/66216468/how-to-make-a-swiftui-sheet-size-match-the-width-height-of-window-on-macos
                })
                .sheet(isPresented: $showCreateCategory,
                       content: {
                    NavigationStack {
                        CreateCategoryView().frame(minWidth: 800, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .center)
                    }
                })
                .sheet(isPresented: $showAccountDetails,
                       content: {
                    NavigationStack {
                        LoginView().frame(minWidth: 800, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .center)
                    }
                })
            
                .sheet(item: $expenseEdit) {
                    expenseEdit = nil
                } content: {item in
                    EditExpenseView(item: item).frame(minWidth: 800, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

#Preview {
    ContentView()
}

