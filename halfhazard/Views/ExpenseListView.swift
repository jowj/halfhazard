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
    var isInSplitView: Bool = false
    
    // AppNavigation reference
    var appNavigationRef: AppNavigation
    
    var body: some View {
        // macOS still uses the split view approach
        if isInSplitView {
            // In split view, don't wrap in NavigationStack (it's in the main view)
            expenseListContent
        } else {
            // Always use the content directly on iOS - navigation is handled by the parent NavigationStack
            expenseListContent
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
                            // Check if there are any unsettled expenses
                            let hasUnsettledExpenses = !expenseViewModel.filteredExpenses.isEmpty && 
                                                      expenseViewModel.filteredExpenses.contains(where: { !$0.settled })
                            
                            if hasUnsettledExpenses {
                                // Only show "Has Unsettled Expenses" when we actually have unsettled expenses
                                Label("Has Unsettled Expenses", systemImage: "circle")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                            } else {
                                // In all other cases, show "All Settled"
                                Label("All Settled", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.headline)
                            }
                        }
                        
                        // Description text based on status
                        if expenseViewModel.filteredExpenses.isEmpty {
                            Text("No expenses to display")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if expenseViewModel.filteredExpenses.allSatisfy({ $0.settled }) {
                            Text("All current expenses are settled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Some expenses need to be settled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Only show the "Settle All" button if there are unsettled expenses
                    let hasUnsettledExpenses = expenseViewModel.filteredExpenses.contains(where: { !$0.settled })
                    
                    if hasUnsettledExpenses {
                        Button(action: {
                            showSettleConfirmation = true
                        }) {
                            Label("Settle All Expenses", systemImage: "checkmark.circle")
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .background(getBannerColor())
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
                        if !isInSplitView {
                            // Use unified navigation on iOS
                            appNavigationRef.showExpenseDetail(expense: expense)
                        } else {
                            // Use view model navigation for macOS
                            expenseViewModel.selectExpense(expense)
                        }
                    }
                    .contextMenu {
                        // Only show edit option if user is the creator or group admin
                        if let currentUserId = expenseViewModel.currentUser?.uid,
                           (expense.createdBy == currentUserId || group.createdBy == currentUserId) {
                            Button {
                                // Prepare expense for editing
                                expenseViewModel.prepareExpenseForEditing(expense)
                                
                                if !isInSplitView {
                                    // Use unified navigation on iOS
                                    appNavigationRef.showEditExpenseForm(expense: expense)
                                } else {
                                    // TODO: Handle macOS navigation
                                }
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
                                if !isInSplitView {
                                    // Use unified navigation on iOS
                                    appNavigationRef.showExpenseDetail(expense: expense)
                                } else {
                                    // Use view model navigation
                                    expenseViewModel.selectExpense(expense)
                                }
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
                // Filter toggle button
                Button(action: {
                    expenseViewModel.toggleActiveFilter()
                }) {
                    Label(
                        expenseViewModel.showOnlyActive ? "Show All Expenses" : "Show Active Only",
                        systemImage: expenseViewModel.showOnlyActive ? "eye" : "eye.fill"
                    )
                }
                .buttonStyle(.bordered)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: {
                        if !isInSplitView {
                            // Use unified navigation on iOS
                            appNavigationRef.showCreateExpenseForm()
                        } else {
                            // Use view model navigation for macOS
                            expenseViewModel.showCreateExpenseForm()
                        }
                    }) {
                        Label("Add Expense", systemImage: "plus")
                    }
                    
                    Divider()
                    
                    // Export option
                    Button(action: {
                        exportExpensesToCSV()
                    }) {
                        Label("Export Expenses as CSV", systemImage: "arrow.down.doc")
                    }
                    .disabled(expenseViewModel.filteredExpenses.isEmpty)
                    
                    // Import option
                    Button(action: {
                        Task {
                            await expenseViewModel.startImportExpenses()
                        }
                    }) {
                        Label("Import Expenses from CSV", systemImage: "arrow.up.doc")
                    }
                    
                    Divider()
                    
                    // Migration option (for fixing old expenses)
                    Button(action: {
                        Task {
                            await expenseViewModel.migrateAllExpensesForCurrentGroup()
                        }
                    }) {
                        Label("Fix Old Expenses", systemImage: "wrench.and.screwdriver")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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
        .alert("Settle All Expenses", isPresented: $showSettleConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Settle All", role: .destructive) {
                Task {
                    await groupViewModel.settleCurrentGroup()
                }
            }
        } message: {
            Text("This will mark all currently unsettled expenses as settled. This is useful when you've completed all payments in this group and want to start fresh. Continue?")
        }
        
        // Import preview sheet
        .sheet(isPresented: Binding<Bool>(
            get: { expenseViewModel.importState.isPreviewing },
            set: { if !$0 { expenseViewModel.cancelImportExpenses() } }
        )) {
            ImportExpensePreview(viewModel: expenseViewModel)
        }
        .onAppear {
            // Set the ExpenseViewModel appNavigationRef
            expenseViewModel.appNavigationRef = appNavigationRef
        }
    }
    
    // Helper function to get the appropriate banner color based on expense status
    private func getBannerColor() -> Color {
        // If there are no expenses at all, use neutral gray
        if expenseViewModel.filteredExpenses.isEmpty {
            return Color.gray.opacity(0.05)
        }
        
        // If all expenses are settled, use green
        if expenseViewModel.filteredExpenses.allSatisfy({ $0.settled }) {
            return Color.green.opacity(0.1)
        }
        
        // If there are unsettled expenses, use a more noticeable blue
        return Color.blue.opacity(0.15)
    }
    
    // Export all expenses to CSV
    private func exportExpensesToCSV() {
        // Don't export if there are no expenses
        guard !expenseViewModel.filteredExpenses.isEmpty else { return }
        
        Task {
            // First, load member names for better readability
            var memberNames: [String: String] = [:]
            for memberId in group.memberIds {
                do {
                    let user = try await UserService().getUser(uid: memberId)
                    memberNames[memberId] = user.displayName ?? user.email
                } catch {
                    print("Error loading member name for \(memberId): \(error)")
                    memberNames[memberId] = "Unknown User"
                }
            }
            
            // Create a descriptive file name with the group name
            let fileName = "\(group.name)_Expenses_\(Date().formatted(.dateTime.day().month().year()))"
                            .replacingOccurrences(of: " ", with: "_")
                            .replacingOccurrences(of: ":", with: ".")
            
            // Export all expenses as CSV
            let csvContent = Expense.expensesToCSV(expenseViewModel.filteredExpenses, memberNames: memberNames)
            
            // Share the CSV file
            let success = FileExportManager.shareCSV(csvContent, fileName: fileName)
            if !success {
                // Here we would handle failure, but we can't set an errorMessage directly
                // in this view as we don't have an error display mechanism
                print("Failed to export expenses to CSV")
            }
        }
    }
}

