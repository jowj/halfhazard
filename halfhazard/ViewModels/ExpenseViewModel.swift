//
//  ExpenseViewModel.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import Foundation
import FirebaseFirestore
import Combine

class ExpenseViewModel: ObservableObject {
    // Services
    private let expenseService = ExpenseService()
    private let groupService = GroupService()
    
    // State
    @Published var expenses: [Expense] = []
    @Published var selectedExpense: Expense?
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    // Current group data
    @Published var currentGroup: Group?
    
    // Form state
    @Published var newExpenseAmount: Double = 0
    @Published var newExpenseDescription: String = ""
    @Published var newExpenseSplitType: SplitType = .equal
    @Published var newExpenseSplits: [String: Double] = [:]
    @Published var showingCreateExpenseSheet = false
    @Published var showingExpenseDetailSheet = false
    
    // Current context
    private var currentUser: User?
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
                settings: Settings(name: "")
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
            isLoading = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loadedExpenses = try await expenseService.getExpensesForGroup(groupId: targetGroupId)
            expenses = loadedExpenses
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
        guard let groupId = currentGroupId, newExpenseAmount > 0 else { return }
        
        // For dev mode, create a mock expense
        if useDevMode {
            let expenseId = "dev-expense-\(UUID().uuidString)"
            let timestamp = Timestamp()
            let mockExpense = Expense(
                id: expenseId,
                amount: newExpenseAmount,
                description: newExpenseDescription.isEmpty ? nil : newExpenseDescription,
                groupId: groupId,
                createdBy: currentUser?.uid ?? "dev-user",
                createdAt: timestamp,
                splitType: newExpenseSplitType,
                splits: newExpenseSplits.isEmpty ? createDefaultSplits(groupId: groupId) : newExpenseSplits
            )
            
            // Add to our array
            expenses.insert(mockExpense, at: 0)
            
            // Reset form fields
            resetFormFields()
            
            // Close the sheet
            showingCreateExpenseSheet = false
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
            
            // Reset form fields
            resetFormFields()
            
            // Close the sheet
            showingCreateExpenseSheet = false
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
        // For dev mode, just remove from the array
        if useDevMode {
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                expenses.remove(at: index)
            }
            return
        }
        
        do {
            try await expenseService.deleteExpense(expenseId: expense.id)
            
            // Remove from our array
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                expenses.remove(at: index)
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
            }
            return
        }
        
        do {
            try await expenseService.updateExpense(expense)
            
            // Update in our array
            if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
                expenses[index] = expense
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
        self.showingExpenseDetailSheet = true
        print("ExpenseViewModel: Set showingExpenseDetailSheet to \(self.showingExpenseDetailSheet)")
    }
    
    func clearSelectedExpense() {
        print("ExpenseViewModel: Clearing selected expense")
        self.selectedExpense = nil
        self.showingExpenseDetailSheet = false
    }
    
    private func resetFormFields() {
        newExpenseAmount = 0
        newExpenseDescription = ""
        newExpenseSplitType = .equal
        newExpenseSplits = [:]
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
        
        // Create equal splits for all group members
        let memberIds = selectedGroup.memberIds
        if memberIds.isEmpty {
            return [:]
        }
        
        // Calculate equal amount for each member
        let equalAmount = newExpenseAmount / Double(memberIds.count)
        
        // Create dictionary with equal splits for all members
        var splits: [String: Double] = [:]
        for memberId in memberIds {
            splits[memberId] = equalAmount
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
                settings: Settings(name: "")
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
    
    // Development helper methods
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
                splits: createSplits(50.0)
            ),
            Expense(
                id: "mock-expense-2",
                amount: 120.0,
                description: "Office supplies",
                groupId: groupId,
                createdBy: userId,
                createdAt: Timestamp(date: Date().addingTimeInterval(-172800)),
                splitType: .equal,
                splits: createSplits(120.0)
            ),
            Expense(
                id: "mock-expense-3",
                amount: 200.0,
                description: "Conference tickets",
                groupId: groupId,
                createdBy: userId,
                createdAt: Timestamp(date: Date().addingTimeInterval(-259200)),
                splitType: .equal,
                splits: createSplits(200.0)
            )
        ]
        
        expenses = mockExpenses
    }
}