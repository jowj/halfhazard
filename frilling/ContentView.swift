// This contains the *primary*, default view of the app.
//  ContentView.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI
import SwiftData

struct ContentView: View {

    @State private var showCreate = false
    @State private var expenseEdit: Expense?
    @Query(
        filter: #Predicate { (expense: Expense) in expense.isCompleted == false },
        sort: \.timestamp,
        order: .reverse
    ) private var items: [Expense]
    @Environment(\.modelContext) var context
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
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
                                .font(.largeTitle)
                        }
                        .tint(.orange)
                        
                        Button(role: .destructive) {
                            withAnimation {
                                expenseEdit = item
                            }
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .symbolVariant(.circle.fill)
                                .font(.largeTitle)
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
                                .font(.largeTitle)
                        }
                    }

                }
            }
                .navigationTitle("HalfHazard Budgetting")
                .toolbar {
                    ToolbarItem {
                        Button {
                            showCreate.toggle()
                        } label: {
                            Label("Add Item", systemImage: "plus")
                        }

                    }
                }
                .sheet(isPresented: $showCreate,
                       content: {
                    NavigationStack {
                        CreateExpenseView()
                    }
                    .presentationDetents([.medium])
                })
                .sheet(item: $expenseEdit) {
                    expenseEdit = nil
                } content: {item in
                    EditExpenseView(item: item)
            }
        }
    }
}

#Preview {
    ContentView()
}

