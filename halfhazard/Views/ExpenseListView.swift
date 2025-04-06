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
    
    // On iOS, we'll optionally use environment object for navigation
    @State private var hasAppNavigation = false
    var appNavigationRef: AppNavigation?
    
    var body: some View {
        // macOS still uses the split view approach
        if isInSplitView {
            // In split view, don't wrap in NavigationStack (it's in the main view)
            expenseListContent
        } else {
            // On iOS, check if we're using the new navigation approach
            if hasAppNavigation {
                // We're using the unified navigation approach
                expenseListContent
            } else {
                // We're using the original approach with separate navigation stacks
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
                            if !expenseViewModel.filteredExpenses.isEmpty && expenseViewModel.filteredExpenses.allSatisfy({ $0.settled }) {
                                Label("All Settled", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.headline)
                            } else {
                                Label("Has Unsettled Expenses", systemImage: "circle")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                            }
                        }
                        
                        // Description text based on status
                        if !expenseViewModel.filteredExpenses.isEmpty && expenseViewModel.filteredExpenses.allSatisfy({ $0.settled }) {
                            Text("All current expenses are settled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if !expenseViewModel.filteredExpenses.isEmpty {
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
            .background(!expenseViewModel.filteredExpenses.isEmpty && expenseViewModel.filteredExpenses.allSatisfy({ $0.settled }) 
                      ? Color.green.opacity(0.1) 
                      : Color.gray.opacity(0.05))
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
                        if hasAppNavigation, let navigation = appNavigationRef {
                            // Use unified navigation on iOS
                            navigation.showExpenseDetail(expense: expense)
                        } else {
                            // Use view model navigation for macOS or iOS without unified navigation
                            expenseViewModel.selectExpense(expense)
                        }
                    }
                    .contextMenu {
                        // Only show edit option if user is the creator or group admin
                        if let currentUserId = expenseViewModel.currentUser?.uid,
                           (expense.createdBy == currentUserId || group.createdBy == currentUserId) {
                            Button {
                                if hasAppNavigation, let navigation = appNavigationRef {
                                    // Use unified navigation on iOS
                                    navigation.showEditExpenseForm(expense: expense)
                                } else {
                                    // Prepare the model and then navigate with view model navigation
                                    expenseViewModel.prepareExpenseForEditing(expense)
                                    expenseViewModel.currentDestination = ExpenseViewModel.Destination.editExpense
                                    expenseViewModel.navigationPath = NavigationPath()
                                    expenseViewModel.navigationPath.append(ExpenseViewModel.Destination.editExpense)
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
                                if hasAppNavigation, let navigation = appNavigationRef {
                                    // Use unified navigation on iOS
                                    navigation.showExpenseDetail(expense: expense)
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
                Menu {
                    Button(action: {
                        if hasAppNavigation, let navigation = appNavigationRef {
                            // Use unified navigation on iOS
                            navigation.showCreateExpenseForm()
                        } else {
                            // Use view model navigation for macOS or iOS without unified navigation
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
            // Mark that we have app navigation if the reference was injected
            hasAppNavigation = appNavigationRef != nil
        }
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

