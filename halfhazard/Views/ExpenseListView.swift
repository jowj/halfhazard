//
//  ExpenseListView.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ExpenseListView: View {
    let group: Group
    @ObservedObject var expenseViewModel: ExpenseViewModel
    
    var body: some View {
        List {
            ForEach(expenseViewModel.expenses, id: \.id) { expense in
                ExpenseRow(expense: expense, group: group)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        expenseViewModel.selectExpense(expense)
                    }
                    .contextMenu {
                        // Only show edit option if user is the creator or group admin
                        if let currentUserId = expenseViewModel.currentUser?.uid,
                           (expense.createdBy == currentUserId || group.createdBy == currentUserId) {
                            Button {
                                expenseViewModel.prepareExpenseForEditing(expense)
                            } label: {
                                Label("Edit Expense", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                Task {
                                    await expenseViewModel.deleteExpense(expense: expense)
                                }
                            } label: {
                                Label("Delete Expense", systemImage: "trash")
                            }
                        } else {
                            // For non-owners/non-admins, just show view details option
                            Button {
                                expenseViewModel.selectExpense(expense)
                            } label: {
                                Label("View Details", systemImage: "eye")
                            }
                        }
                    }
            }
        }
        .overlay {
            if expenseViewModel.expenses.isEmpty && !expenseViewModel.isLoading {
                ContentUnavailableView("No Expenses", 
                                     systemImage: "dollarsign.circle",
                                     description: Text("Add an expense to get started"))
            }
            
            if expenseViewModel.isLoading {
                ProgressView()
            }
        }
        .listStyle(.plain)
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    expenseViewModel.showingCreateExpenseSheet = true
                }) {
                    Label("Add Expense", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $expenseViewModel.showingCreateExpenseSheet) {
            CreateExpenseForm(viewModel: expenseViewModel)
                .frame(minWidth: 700, maxWidth: .infinity, minHeight: 700, maxHeight: .infinity)
        }
        .sheet(isPresented: $expenseViewModel.showingExpenseDetailSheet) {
            if let selectedExpense = expenseViewModel.selectedExpense {
                ExpenseDetailView(expense: selectedExpense, group: group, expenseViewModel: expenseViewModel)
                    .frame(minWidth: 600, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
                    .onDisappear {
                        // Clear selection when sheet is dismissed
                        expenseViewModel.clearSelectedExpense()
                    }
            }
        }
        .sheet(isPresented: $expenseViewModel.showingEditExpenseSheet) {
            EditExpenseForm(viewModel: expenseViewModel)
                .frame(minWidth: 500, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        }
        .onAppear {
            // Load expenses when view appears, if needed
            if expenseViewModel.currentGroupId != group.id || expenseViewModel.expenses.isEmpty {
                Task {
                    await expenseViewModel.loadExpenses(forGroupId: group.id)
                }
            }
        }
    }
}

#Preview {
    ExpenseListView(
        group: Group(
            id: "preview-group",
            name: "Preview Group",
            memberIds: ["user1"],
            createdBy: "user1",
            createdAt: Timestamp(),
            settings: Settings(name: "")
        ),
        expenseViewModel: ExpenseViewModel(currentUser: nil, currentGroupId: "preview-group", useDevMode: true)
    )
}