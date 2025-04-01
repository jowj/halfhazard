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
    @ObservedObject var groupViewModel: GroupViewModel
    @State private var showSettleConfirmation = false
    @State private var showUnsettleConfirmation = false
    var isInSplitView: Bool = false
    
    var body: some View {
        if isInSplitView {
            // In split view, don't wrap in NavigationStack (it's in the main view)
            expenseListContent
        } else {
            // On iOS, use NavigationStack here
            NavigationStack {
                if expenseViewModel.navigationPath.isEmpty {
                    expenseListContent
                } else {
                    // Display the correct destination based on navigation state
                    if let dest = expenseViewModel.navigationDestination {
                        switch dest {
                        case .createExpense:
                            CreateExpenseForm(viewModel: expenseViewModel)
                                .navigationTitle("Add Expense")
                        case .editExpense:
                            EditExpenseForm(viewModel: expenseViewModel)
                                .navigationTitle("Edit Expense")
                        case .expenseDetail(let expense):
                            ExpenseDetailView(expense: expense, group: group, expenseViewModel: expenseViewModel)
                                .navigationTitle("Expense Details")
                        }
                    } else {
                        // Fallback
                        expenseListContent
                    }
                }
            }
        }
    }
    
    private var expenseListContent: some View {
        VStack(spacing: 0) {
            // Settlement status banner
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Status info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            // Status label
                            if group.settled {
                                Label("Settled", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.headline)
                            } else {
                                Label("Active", systemImage: "circle")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                            }
                            
                            // Settled date if available
                            if let settledAt = group.settledAt {
                                Text("on \(settledAt.dateValue().formatted(date: .abbreviated, time: .shortened))")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                        }
                        
                        // Description text based on status
                        if group.settled {
                            Text("All expenses in this group have been marked as settled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Action button based on current state
                    if group.settled {
                        Button(action: {
                            showUnsettleConfirmation = true
                        }) {
                            Label("Reactivate Group", systemImage: "arrow.counterclockwise")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(action: {
                            showSettleConfirmation = true
                        }) {
                            Label("Mark All as Settled", systemImage: "checkmark.circle")
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .background(group.settled ? Color.green.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.2)),
                alignment: .bottom
            )
            
            // Expense list
            List {
                ForEach(expenseViewModel.filteredExpenses, id: \.id) { expense in
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
                                // Prepare the model and then navigate
                                expenseViewModel.prepareExpenseForEditing(expense)
                                expenseViewModel.currentDestination = ExpenseViewModel.Destination.editExpense
                                expenseViewModel.navigationPath = NavigationPath()
                                expenseViewModel.navigationPath.append(ExpenseViewModel.Destination.editExpense)
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
        }
        .overlay {
            if expenseViewModel.filteredExpenses.isEmpty && !expenseViewModel.isLoading {
                if expenseViewModel.showOnlyActive && !expenseViewModel.expenses.isEmpty {
                    ContentUnavailableView("No Active Expenses", 
                                         systemImage: "checkmark.circle",
                                         description: Text("All expenses are settled"))
                } else {
                    ContentUnavailableView("No Expenses", 
                                         systemImage: "dollarsign.circle",
                                         description: Text("Add an expense to get started"))
                }
            }
            
            if expenseViewModel.isLoading {
                ProgressView()
            }
        }
        .listStyle(.plain)
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                // Filter toggle
                Picker("Filter", selection: $expenseViewModel.showOnlyActive) {
                    Text("All Expenses").tag(false)
                    Text("Active Only").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: expenseViewModel.showOnlyActive) { _, _ in
                    expenseViewModel.toggleActiveFilter()
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    expenseViewModel.showCreateExpenseForm()
                }) {
                    Label("Add Expense", systemImage: "plus")
                }
            }
        }
                // NavigationDestination now defined in the main content view
        .onAppear {
            // Load expenses when view appears, if needed
            if expenseViewModel.currentGroupId != group.id || expenseViewModel.expenses.isEmpty {
                Task {
                    await expenseViewModel.loadExpenses(forGroupId: group.id)
                }
            }
        }
        // Settle confirmation alert
        .alert("Settle Group", isPresented: $showSettleConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Settle All", role: .destructive) {
                Task {
                    await groupViewModel.settleCurrentGroup()
                }
            }
        } message: {
            Text("This will mark all expenses in this group as settled. Members will still be able to view the group and expenses, but they will be marked as paid. Continue?")
        }
        
        // Unsettle confirmation alert
        .alert("Reactivate Group", isPresented: $showUnsettleConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reactivate", role: .none) {
                Task {
                    await groupViewModel.unsettleCurrentGroup()
                }
            }
        } message: {
            Text("This will mark the group as active again. Individual expenses will remain in their current state. Continue?")
        }
    }
}

