//
//  ExpenseViewModel.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import Foundation
import FirebaseFirestore
import Combine
import SwiftUI

class ExpenseViewModel: ObservableObject {
    // Services
    private let expenseService = ExpenseService()
    private let groupService = GroupService()
    
    // State
    @Published var expenses: [Expense] = []
    @Published var filteredExpenses: [Expense] = []
    @Published var selectedExpense: Expense?
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    // Filter state
    @Published var showOnlyActive = false
    
    // Current group data
    @Published var currentGroup: Group?
    
    // Form state
    @Published var newExpenseAmount: Double = 0
    @Published var newExpenseDescription: String = ""
    @Published var newExpenseSplitType: SplitType = .equal
    @Published var newExpenseSplits: [String: Double] = [:]
    @Published var editingExpense: Expense? = nil
    
    // AppNavigation reference
    var appNavigationRef: AppNavigation?
    
    // Current context
    // Make currentUser public so views can access it
    var currentUser: User?
    // Make currentGroupId public so views can access it
    var currentGroupId: String?
    
    // Development mode
    private var useDevMode = false
    
    init(currentUser: User?, currentGroupId: String? = nil, useDevMode: Bool = false) {
        self.currentUser = currentUser
        self.currentGroupId = currentGroupId
        self.useDevMode = useDevMode
        
        // If we have a group ID, load the group
        if let groupId = currentGroupId {
            Task {
                await loadGroupInfo(groupId: groupId)
            }
        }
        
        // Listen for refresh notifications from GroupViewModel
        NotificationCenter.default.addObserver(self, selector: #selector(refreshExpensesFromNotification), name: NSNotification.Name("RefreshExpensesNotification"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func refreshExpensesFromNotification() {
        Task {
            await MainActor.run {
                if let groupId = currentGroupId {
                    Task {
                        await loadExpenses(forGroupId: groupId)
                    }
                }
            }
        }
    }
    
    @MainActor
    private func loadGroupInfo(groupId: String) async {
        guard !useDevMode else {
            // Create mock group in dev mode
            self.currentGroup = Group(
                id: groupId,
                name: "Mock Group",
                memberIds: [
                    currentUser?.uid ?? "dev-user",
                    "dev-user-2",
                    "dev-user-3"
                ],
                createdBy: currentUser?.uid ?? "dev-user",
                createdAt: Timestamp(),
                settings: Settings(name: ""),
                settled: false,
                settledAt: nil
            )
            return
        }
        
        do {
            let group = try await groupService.getGroupInfo(groupID: groupId)
            self.currentGroup = group
        } catch {
            print("Error loading group info: \(error)")
            // We don't set errorMessage here to avoid UI disruption
        }
    }
    
    @MainActor
    func loadExpenses(forGroupId groupId: String? = nil) async {
        // Use provided groupId or fall back to the stored one
        let targetGroupId = groupId ?? currentGroupId
        
        // Update the stored group ID if a new one was provided
        if let groupId = groupId {
            currentGroupId = groupId
        }
        
        // Make sure we have a group ID
        guard let targetGroupId = targetGroupId else {
            errorMessage = "No group selected"
            return
        }
        
        // Skip for dev mode since we don't have real Firebase data
        if useDevMode {
            // Create mock expenses
            if expenses.isEmpty {
                createMockExpenses(for: targetGroupId)
            }
            applyFilters()
            isLoading = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loadedExpenses = try await expenseService.getExpensesForGroup(groupId: targetGroupId)
            
            // Check if any expenses need payment migration
            let expensesNeedingMigration = loadedExpenses.filter { $0.payments.isEmpty }
            
            if !expensesNeedingMigration.isEmpty {
                print("Migrating \(expensesNeedingMigration.count) expenses with missing payment data...")
                do {
                    let migratedExpenses = try await expenseService.migrateMultipleExpenses(expensesNeedingMigration)
                    
                    // Replace migrated expenses in the loaded list
                    var updatedExpenses = loadedExpenses
                    for migratedExpense in migratedExpenses {
                        if let index = updatedExpenses.firstIndex(where: { $0.id == migratedExpense.id }) {
                            updatedExpenses[index] = migratedExpense
                        }
                    }
                    
                    expenses = updatedExpenses
                    print("Migration completed successfully")
                } catch {
                    print("Migration failed: \(error). Using original expenses.")
                    expenses = loadedExpenses
                }
            } else {
                expenses = loadedExpenses
            }
            
            applyFilters()
        } catch let error as NSError {
            if error.domain == "ExpenseService" && error.code == 9,
               let indexURL = error.userInfo["indexURL"] as? String {
                // Handle missing Firestore index
                errorMessage = """
                Missing Firestore index for expenses.
                
                Create the index using this link:
                \(indexURL)
                
                After creating the index, restart the app.
                """
            } else if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                // Handle permissions error
                errorMessage = """
                Firestore permissions error.
                
                You need to set up Firestore security rules. Please:
                1. Go to Firebase Console -> Firestore Database
                2. Go to the Rules tab
                3. Replace rules with the content from the firestore.rules.dev file for development
                4. Publish the rules
                
                For development, you can use permissive rules. Make sure to use proper rules in production.
                """
            } else if error.domain == "ExpenseService" && error.code == 403 {
                // Handle access control error - user not a member of the group
                errorMessage = "Access denied: \(error.localizedDescription)"
                expenses = [] // Clear expenses since we don't have access
            } else if error.domain == "ExpenseService" && error.code == 401 {
                // Handle authentication error
                errorMessage = "Authentication required: \(error.localizedDescription)"
                expenses = [] // Clear expenses since we're not authenticated
            } else {
                // Handle generic error
                errorMessage = "Failed to load expenses: \(error.localizedDescription)"
            }
            print("Error loading expenses: \(error)")
        }
    }
    
    @MainActor
    func createExpense() async {
        guard let groupId = currentGroupId else {
            errorMessage = "No group selected"
            return
        }
        
        guard newExpenseAmount > 0 else {
            errorMessage = "Expense amount must be greater than zero"
            return
        }
        
        // For dev mode, create a mock expense
        if useDevMode {
            let expenseId = "dev-expense-\(UUID().uuidString)"
            let timestamp = Timestamp()
            let splits = newExpenseSplits.isEmpty ? createDefaultSplits(groupId: groupId) : newExpenseSplits
            
            // Creator has paid the full amount upfront
            var payments: [String: Double] = [:]
            let creatorId = currentUser?.uid ?? "dev-user"
            payments[creatorId] = newExpenseAmount
            
            let mockExpense = Expense(
                id: expenseId,
                amount: newExpenseAmount,
                description: newExpenseDescription.isEmpty ? nil : newExpenseDescription,
                groupId: groupId,
                createdBy: creatorId,
                createdAt: timestamp,
                splitType: newExpenseSplitType,
                splits: splits,
                payments: payments,
                settled: false,
                settledAt: nil
            )
            
            // Add to our array
            expenses.insert(mockExpense, at: 0)
            applyFilters()
            
            // Reset form fields
            resetFormFields()
            
            // Clear navigation
            clearNavigation()
            
            // Notify about expense change for balance updates
            NotificationCenter.default.post(name: NSNotification.Name("ExpenseChangedNotification"), object: nil, userInfo: ["groupId": groupId])
            return
        }
        
        do {
            let description = newExpenseDescription.isEmpty ? nil : newExpenseDescription
            let splits = newExpenseSplits.isEmpty ? createDefaultSplits(groupId: groupId) : newExpenseSplits
            
            let expense = try await expenseService.createExpense(
                amount: newExpenseAmount,
                description: description,
                groupId: groupId,
                splitType: newExpenseSplitType,
                splits: splits
            )
            
            // Add the new expense to our array
            expenses.insert(expense, at: 0)
            applyFilters()
            
            // Reset form fields
            resetFormFields()
            
            // Clear navigation
            clearNavigation()
            
            // Notify about expense change for balance updates
            NotificationCenter.default.post(name: NSNotification.Name("ExpenseChangedNotification"), object: nil, userInfo: ["groupId": groupId])
        } catch let error as NSError {
            if error.domain == "ExpenseService" && error.code == 403 {
                // Access control error
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "ExpenseService" && error.code == 401 {
                // Authentication error
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to create expense: \(error.localizedDescription)"
            }
            print("Error creating expense: \(error)")
        }
    }
    
    @MainActor
    func deleteExpense(expense: Expense) async {
        // Check if current user is the creator of the expense
        guard expense.createdBy == currentUser?.uid else {
            errorMessage = "You don't have permission to delete this expense"
            return
        }
        
        // For dev mode, just remove from the array
        if useDevMode {
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                expenses.remove(at: index)
                applyFilters()
            }
            return
        }
        
        do {
            try await expenseService.deleteExpense(expenseId: expense.id)
            
            // Remove from our array
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                expenses.remove(at: index)
                applyFilters()
            }
        } catch let error as NSError {
            if error.domain == "ExpenseService" && error.code == 403 {
                // Access control error
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "ExpenseService" && error.code == 401 {
                // Authentication error
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to delete expense: \(error.localizedDescription)"
            }
            print("Error deleting expense: \(error)")
        }
    }
    
    @MainActor
    func updateExpense(_ expense: Expense) async {
        // For dev mode, just update in the array
        if useDevMode {
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                expenses[index] = expense
                applyFilters()
            }
            return
        }
        
        do {
            try await expenseService.updateExpense(expense)
            
            // Update in our array
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                expenses[index] = expense
                applyFilters()
            }
        } catch let error as NSError {
            if error.domain == "ExpenseService" && error.code == 403 {
                // Access control error
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "ExpenseService" && error.code == 401 {
                // Authentication error
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to update expense: \(error.localizedDescription)"
            }
            print("Error updating expense: \(error)")
        }
    }
    
    func selectExpense(_ expense: Expense) {
        print("ExpenseViewModel: Selecting expense \(expense.id)")
        self.selectedExpense = expense
        
        // Use AppNavigation if available
        if let appNavigation = appNavigationRef {
            appNavigation.showExpenseDetail(expense: expense)
        }
    }
    
    func clearSelectedExpense() {
        print("ExpenseViewModel: Clearing selected expense")
        self.selectedExpense = nil
    }
    
    func prepareExpenseForEditing(_ expense: Expense) {
        print("ExpenseViewModel: Preparing expense for editing: \(expense.id)")
        
        // Store the expense being edited
        self.editingExpense = expense
        
        // Setup form fields
        self.newExpenseAmount = expense.amount
        self.newExpenseDescription = expense.description ?? ""
        self.newExpenseSplitType = expense.splitType
        self.newExpenseSplits = expense.splits
    }
    
    func showCreateExpenseForm() {
        print("ExpenseViewModel: Showing create expense form")
        
        // Use AppNavigation if available
        appNavigationRef?.showCreateExpenseForm()
    }
    
    // Helper methods that use AppNavigation
    func navigateBack() {
        appNavigationRef?.navigateBack()
    }
    
    func clearNavigation() {
        appNavigationRef?.clearNavigation()
    }
    
    @MainActor
    func saveEditedExpense() async {
        guard let editingExpense = editingExpense, newExpenseAmount > 0 else { return }
        
        // Create an updated expense
        var updatedExpense = editingExpense
        updatedExpense.amount = newExpenseAmount
        updatedExpense.description = newExpenseDescription.isEmpty ? nil : newExpenseDescription
        updatedExpense.splitType = newExpenseSplitType
        
        // If the split type changed or amount changed, recalculate splits
        if updatedExpense.splitType != editingExpense.splitType || updatedExpense.amount != editingExpense.amount {
            if newExpenseSplits.isEmpty {
                // If no custom splits were defined, create default splits
                updatedExpense.splits = createDefaultSplits(groupId: editingExpense.groupId)
            } else {
                updatedExpense.splits = newExpenseSplits
            }
        } else {
            // Otherwise keep the existing splits
            updatedExpense.splits = newExpenseSplits.isEmpty ? editingExpense.splits : newExpenseSplits
        }
        
        // For dev mode, just update in the array
        if useDevMode {
            if let index = expenses.firstIndex(where: { $0.id == updatedExpense.id }) {
                expenses[index] = updatedExpense
            }
            
            // Reset form fields
            resetFormFields()
            
            // Clear navigation
            clearNavigation()
            return
        }
        
        do {
            try await expenseService.updateExpense(updatedExpense)
            
            // Update in our array
            if let index = expenses.firstIndex(where: { $0.id == updatedExpense.id }) {
                expenses[index] = updatedExpense
            }
            
            // Reset form fields
            resetFormFields()
            
            // Clear navigation
            clearNavigation()
            
            // If this was the selected expense, update it
            if selectedExpense?.id == updatedExpense.id {
                selectedExpense = updatedExpense
            }
        } catch let error as NSError {
            if error.domain == "ExpenseService" && error.code == 403 {
                // Access control error
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "ExpenseService" && error.code == 401 {
                // Authentication error
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to update expense: \(error.localizedDescription)"
            }
            print("Error updating expense: \(error)")
        }
    }
    
    private func resetFormFields() {
        newExpenseAmount = 0
        newExpenseDescription = ""
        newExpenseSplitType = .equal
        newExpenseSplits = [:]
        editingExpense = nil
    }
    
    private func createDefaultSplits(groupId: String) -> [String: Double] {
        // Find the currently selected group to get its members
        guard let selectedGroup = findSelectedGroup(withId: groupId) else {
            // Fall back to current user only if we can't find the group
            guard let currentUserId = currentUser?.uid else {
                return [:]
            }
            return [currentUserId: newExpenseAmount]
        }
        
        // Get all members in the group
        let memberIds = selectedGroup.memberIds
        if memberIds.isEmpty {
            return [:]
        }
        
        // Get current user ID
        guard let currentUserId = currentUser?.uid else {
            return [:]
        }
        
        var splits: [String: Double] = [:]
        
        // Handle different split types
        switch newExpenseSplitType {
            case .equal:
                // Calculate equal amount for each member
                let equalAmount = newExpenseAmount / Double(memberIds.count)
                
                // Create dictionary with equal splits for all members
                for memberId in memberIds {
                    splits[memberId] = equalAmount
                }
                
            case .currentUserOwed:
                // Current user is owed the full amount - other members owe money
                let otherMemberIds = memberIds.filter { $0 != currentUserId }
                
                if otherMemberIds.isEmpty {
                    // Edge case: Current user is the only member
                    splits[currentUserId] = 0
                } else {
                    // Set splits: other members split the amount equally, current user gets 0
                    let amountPerMember = newExpenseAmount / Double(otherMemberIds.count)
                    
                    // Current user pays nothing (or technically gets "negative" split representing being owed)
                    splits[currentUserId] = 0
                    
                    // Other members all pay their share
                    for memberId in otherMemberIds {
                        splits[memberId] = amountPerMember
                    }
                }
                
            case .currentUserOwes:
                // Current user owes the full amount - current user pays everything
                for memberId in memberIds {
                    if memberId == currentUserId {
                        // Current user pays the full amount
                        splits[memberId] = newExpenseAmount
                    } else {
                        // Other members pay nothing
                        splits[memberId] = 0
                    }
                }
                
            case .custom:
                // For custom, just create equal splits as a starting point
                let equalAmount = newExpenseAmount / Double(memberIds.count)
                for memberId in memberIds {
                    splits[memberId] = equalAmount
                }
        }
        
        return splits
    }
    
    // Helper method to find a group by ID
    private func findSelectedGroup(withId groupId: String) -> Group? {
        // First, check if this is our current group
        if let currentGroup = self.currentGroup, currentGroup.id == groupId {
            return currentGroup
        }
        
        // If we're in dev mode, create a mock group
        if useDevMode {
            // In dev mode, create a mock group with the current user and some fake members
            return Group(
                id: groupId,
                name: "Mock Group",
                memberIds: [
                    currentUser?.uid ?? "dev-user",
                    "dev-user-2",
                    "dev-user-3"
                ],
                createdBy: currentUser?.uid ?? "dev-user",
                createdAt: Timestamp(),
                settings: Settings(name: ""),
                settled: false,
                settledAt: nil
            )
        }
        
        // In a production implementation, we'd fetch this from Firestore if needed
        // For now we'll return nil and rely on the loadGroupInfo method to populate currentGroup
        return nil
    }
    
    // Update context
    @MainActor
    func updateContext(user: User?, groupId: String?, devMode: Bool) {
        self.currentUser = user
        
        // Only update group ID if it's different (to avoid unnecessary reloads)
        if groupId != currentGroupId {
            self.currentGroupId = groupId
            
            // Load the new group info
            if let groupId = groupId {
                Task {
                    await loadGroupInfo(groupId: groupId)
                }
            } else {
                self.currentGroup = nil
            }
        }
        
        self.useDevMode = devMode
    }
    
    @MainActor
    func settleExpense(expense: Expense) async {
        // Check if expense is already settled
        guard !expense.settled else {
            errorMessage = "This expense is already settled"
            return
        }
        
        // For dev mode, just update in the array
        if useDevMode {
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                var updatedExpense = expense
                updatedExpense.settled = true
                updatedExpense.settledAt = Timestamp()
                expenses[index] = updatedExpense
                applyFilters()
                
                // Update selected expense if it's the one we just settled
                if selectedExpense?.id == expense.id {
                    selectedExpense = updatedExpense
                }
                
                // Notify about expense change for balance updates
                NotificationCenter.default.post(name: NSNotification.Name("ExpenseChangedNotification"), object: nil, userInfo: ["groupId": expense.groupId])
            }
            return
        }
        
        do {
            try await expenseService.settleExpense(expenseId: expense.id)
            
            // Update in our array
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                var updatedExpense = expense
                updatedExpense.settled = true
                updatedExpense.settledAt = Timestamp()
                expenses[index] = updatedExpense
                applyFilters()
                
                // Update selected expense if it's the one we just settled
                if selectedExpense?.id == expense.id {
                    selectedExpense = updatedExpense
                }
                
                // Notify about expense change for balance updates
                NotificationCenter.default.post(name: NSNotification.Name("ExpenseChangedNotification"), object: nil, userInfo: ["groupId": expense.groupId])
            }
        } catch let error as NSError {
            if error.domain == "ExpenseService" && error.code == 400 {
                errorMessage = "This expense is already settled"
            } else if error.domain == "ExpenseService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "ExpenseService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to settle expense: \(error.localizedDescription)"
            }
            print("Error settling expense: \(error)")
        }
    }
    
    @MainActor
    func unsettleExpense(expense: Expense) async {
        // Check if expense is already unsettled
        guard expense.settled else {
            errorMessage = "This expense is already unsettled"
            return
        }
        
        // For dev mode, just update in the array
        if useDevMode {
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                var updatedExpense = expense
                updatedExpense.settled = false
                updatedExpense.settledAt = nil
                expenses[index] = updatedExpense
                applyFilters()
                
                // Update selected expense if it's the one we just unsettled
                if selectedExpense?.id == expense.id {
                    selectedExpense = updatedExpense
                }
            }
            return
        }
        
        do {
            try await expenseService.unsettleExpense(expenseId: expense.id)
            
            // Update in our array
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                var updatedExpense = expense
                updatedExpense.settled = false
                updatedExpense.settledAt = nil
                expenses[index] = updatedExpense
                applyFilters()
                
                // Update selected expense if it's the one we just unsettled
                if selectedExpense?.id == expense.id {
                    selectedExpense = updatedExpense
                }
            }
        } catch let error as NSError {
            if error.domain == "ExpenseService" && error.code == 400 {
                errorMessage = "This expense is already unsettled"
            } else if error.domain == "ExpenseService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "ExpenseService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to unsettle expense: \(error.localizedDescription)"
            }
            print("Error unsettling expense: \(error)")
        }
    }
    
    @MainActor
    func loadUnsettledExpenses(forGroupId groupId: String? = nil) async {
        // Use provided groupId or fall back to the stored one
        let targetGroupId = groupId ?? currentGroupId
        
        // Update the stored group ID if a new one was provided
        if let groupId = groupId {
            currentGroupId = groupId
        }
        
        // Make sure we have a group ID
        guard let targetGroupId = targetGroupId else {
            errorMessage = "No group selected"
            return
        }
        
        // Skip for dev mode - filter existing expenses
        if useDevMode {
            if expenses.isEmpty {
                createMockExpenses(for: targetGroupId)
            }
            // Filter to only show unsettled expenses
            expenses = expenses.filter { !$0.settled }
            isLoading = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loadedExpenses = try await expenseService.getUnsettledExpensesForGroup(groupId: targetGroupId)
            expenses = loadedExpenses
        } catch let error as NSError {
            handleExpenseLoadingError(error)
        }
    }
    
    private func handleExpenseLoadingError(_ error: NSError) {
        if error.domain == "ExpenseService" && error.code == 9,
           let indexURL = error.userInfo["indexURL"] as? String {
            // Handle missing Firestore index
            errorMessage = """
            Missing Firestore index for expenses.
            
            Create the index using this link:
            \(indexURL)
            
            After creating the index, restart the app.
            """
        } else if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
            // Handle permissions error
            errorMessage = """
            Firestore permissions error.
            
            You need to set up Firestore security rules. Please:
            1. Go to Firebase Console -> Firestore Database
            2. Go to the Rules tab
            3. Replace rules with the content from the firestore.rules.dev file for development
            4. Publish the rules
            
            For development, you can use permissive rules. Make sure to use proper rules in production.
            """
        } else if error.domain == "ExpenseService" && error.code == 403 {
            // Handle access control error - user not a member of the group
            errorMessage = "Access denied: \(error.localizedDescription)"
            expenses = [] // Clear expenses since we don't have access
            filteredExpenses = []
        } else if error.domain == "ExpenseService" && error.code == 401 {
            // Handle authentication error
            errorMessage = "Authentication required: \(error.localizedDescription)"
            expenses = [] // Clear expenses since we're not authenticated
            filteredExpenses = []
        } else {
            // Handle generic error
            errorMessage = "Failed to load expenses: \(error.localizedDescription)"
        }
        print("Error loading expenses: \(error)")
    }
    
    // Apply filters to the expenses array and update filteredExpenses
    private func applyFilters() {
        if showOnlyActive {
            // Only show unsettled (active) expenses
            filteredExpenses = expenses.filter { !$0.settled }
        } else {
            // Show all expenses
            filteredExpenses = expenses
        }
    }
    
    // Toggle between showing all expenses or only active (unsettled) ones
    func toggleActiveFilter() {
        showOnlyActive.toggle()
        applyFilters()
    }
    
    // MARK: - CSV Import
    
    /// Model for tracking the state of expense import
    struct ImportState {
        var isImporting = false
        var isPreviewing = false
        var parsedExpenses: [Expense] = []
        var invalidRows: [Int] = []
        var errorMessages: [String] = []
        var fileName: String = ""
        
        var previewCount: Int {
            // Show maximum 5 expenses in preview
            return min(parsedExpenses.count, 5)
        }
        
        var hasErrors: Bool {
            return !errorMessages.isEmpty
        }
        
        var summary: String {
            let validCount = parsedExpenses.count
            let invalidCount = invalidRows.count
            
            var result = "Successfully parsed \(validCount) expense(s)"
            if invalidCount > 0 {
                result += " with \(invalidCount) invalid row(s)"
            }
            return result
        }
        
        mutating func reset() {
            isImporting = false
            isPreviewing = false
            parsedExpenses = []
            invalidRows = []
            errorMessages = []
            fileName = ""
        }
    }
    
    @Published var importState = ImportState()
    
    /// Starts the import process by opening a file picker for CSV selection
    @MainActor
    func startImportExpenses() async {
        guard let groupId = currentGroupId, let currentUser = currentUser else {
            errorMessage = "No group selected or user not logged in"
            return
        }
        
        // Reset the import state
        importState.reset()
        importState.isImporting = true
        
        // Open file picker and get CSV content
        if let csvData = await FileExportManager.importCSV() {
            let content = csvData.content
            importState.fileName = csvData.fileName
            
            // Get the current group to access member IDs
            guard let group = findSelectedGroup(withId: groupId) else {
                errorMessage = "Could not find the current group information"
                importState.reset()
                return
            }
            
            // Parse the CSV
            let result = Expense.importFromCSV(
                csvString: content, 
                groupId: groupId, 
                creatorId: currentUser.uid, 
                memberIds: group.memberIds
            )
            
            // Update the import state
            importState.parsedExpenses = result.validExpenses
            importState.invalidRows = result.invalidRowIndices
            importState.errorMessages = result.errorMessages
            
            if result.validExpenses.isEmpty {
                // No valid expenses to import
                errorMessage = "No valid expenses found in the CSV file: \(result.errorMessages.joined(separator: ", "))"
                importState.reset()
            } else {
                // Show preview before final import
                importState.isPreviewing = true
            }
        } else {
            // User cancelled or error occurred
            importState.reset()
        }
    }
    
    /// Confirms the import after preview and saves the expenses
    @MainActor
    func confirmImportExpenses() async {
        guard importState.isImporting && importState.isPreviewing else { return }
        
        // Handle dev mode
        if useDevMode {
            // Just add the parsed expenses to our local array
            expenses.append(contentsOf: importState.parsedExpenses)
            applyFilters()
            
            // Reset import state
            importState.reset()
            return
        }
        
        // Actually save the expenses to Firestore
        var createdCount = 0
        var failedCount = 0
        
        for expense in importState.parsedExpenses {
            do {
                // Create each expense in Firestore
                _ = try await expenseService.createExpense(
                    amount: expense.amount,
                    description: expense.description,
                    groupId: expense.groupId,
                    splitType: expense.splitType,
                    splits: expense.splits,
                    settled: expense.settled,
                    createdAt: expense.createdAt
                )
                createdCount += 1
            } catch {
                failedCount += 1
                print("Error creating imported expense: \(error)")
            }
        }
        
        // Reload expenses after import to get the newly created ones
        await loadExpenses()
        
        // Show a summary message
        if failedCount > 0 {
            errorMessage = "Imported \(createdCount) expense(s), but \(failedCount) failed to import."
        }
        
        // Reset import state
        importState.reset()
    }
    
    /// Cancels the import process
    func cancelImportExpenses() {
        importState.reset()
    }
    
    // MARK: - Development helper methods
    
    private func createMockExpenses(for groupId: String) {
        let userId = currentUser?.uid ?? "dev-user"
        
        // Get mock group to create realistic splits
        let mockGroup = findSelectedGroup(withId: groupId)
        let memberIds = mockGroup?.memberIds ?? [userId]
        
        // Create mock splits for all group members
        let createSplits = { (amount: Double) -> [String: Double] in
            var splits: [String: Double] = [:]
            let equalAmount = amount / Double(memberIds.count)
            for memberId in memberIds {
                splits[memberId] = equalAmount
            }
            return splits
        }
        
        let mockExpenses = [
            Expense(
                id: "mock-expense-1",
                amount: 50.0,
                description: "Team lunch",
                groupId: groupId,
                createdBy: userId,
                createdAt: Timestamp(date: Date().addingTimeInterval(-86400)),
                splitType: .equal,
                splits: createSplits(50.0),
                settled: false
            ),
            Expense(
                id: "mock-expense-2",
                amount: 120.0,
                description: "Office supplies",
                groupId: groupId,
                createdBy: userId,
                createdAt: Timestamp(date: Date().addingTimeInterval(-172800)),
                splitType: .equal,
                splits: createSplits(120.0),
                settled: false
            ),
            Expense(
                id: "mock-expense-3",
                amount: 200.0,
                description: "Conference tickets",
                groupId: groupId,
                createdBy: userId,
                createdAt: Timestamp(date: Date().addingTimeInterval(-259200)),
                splitType: .equal,
                splits: createSplits(200.0),
                settled: true,
                settledAt: Timestamp(date: Date().addingTimeInterval(-86400))
            )
        ]
        
        expenses = mockExpenses
    }
    
    // MARK: - Migration
    
    @MainActor
    func migrateAllExpensesForCurrentGroup() async {
        guard let groupId = currentGroupId else {
            errorMessage = "No group selected"
            return
        }
        
        let expensesNeedingMigration = expenses.filter { $0.payments.isEmpty }
        
        if expensesNeedingMigration.isEmpty {
            print("No expenses need migration")
            return
        }
        
        print("Manually migrating \(expensesNeedingMigration.count) expenses...")
        
        do {
            let migratedExpenses = try await expenseService.migrateMultipleExpenses(expensesNeedingMigration)
            
            // Replace migrated expenses in the current list
            for migratedExpense in migratedExpenses {
                if let index = expenses.firstIndex(where: { $0.id == migratedExpense.id }) {
                    expenses[index] = migratedExpense
                }
            }
            
            applyFilters()
            print("Manual migration completed successfully")
        } catch {
            errorMessage = "Failed to migrate expenses: \(error.localizedDescription)"
            print("Manual migration failed: \(error)")
        }
    }
}