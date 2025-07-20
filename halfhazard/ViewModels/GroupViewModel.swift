//
//  GroupViewModel.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import Foundation
import FirebaseFirestore
import Combine
import SwiftUI

class GroupViewModel: ObservableObject {
    // Services
    // Make groupService public so it can be used by views
    let groupService = GroupService()
    
    // State
    @Published var groups: [Group] = []
    @Published var _selectedGroup: Group?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var groupBalances: [String: Double] = [:] // Map of group IDs to user balance
    
    // Custom setter/getter for selectedGroup to add debugging
    var selectedGroup: Group? {
        get {
            return _selectedGroup
        }
        set {
            print("GroupViewModel: Setting selected group to \(newValue?.name ?? "nil")")
            _selectedGroup = newValue
        }
    }
    
    // Form state
    @Published var newGroupName = ""
    @Published var newGroupDescription = ""
    @Published var joinGroupCode = ""
    
    // Navigation state
    @Published var showingLeaveConfirmation = false
    @Published var showingDeleteConfirmation = false
    
    // For iOS navigation
    var appNavigationRef: AppNavigation?
    
    // Current user
    var currentUser: User?
    
    // Development mode
    var useDevMode = false
    
    init(currentUser: User?, useDevMode: Bool = false) {
        self.currentUser = currentUser
        self.useDevMode = useDevMode
        
        // Listen for expense changes to update balances
        NotificationCenter.default.addObserver(self, selector: #selector(handleExpenseChanged), name: NSNotification.Name("ExpenseChangedNotification"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleExpenseChanged(_ notification: Notification) {
        // Get the group ID from the notification
        if let userInfo = notification.userInfo,
           let groupId = userInfo["groupId"] as? String {
            // Update just this group's balance
            Task {
                await calculateUserBalance(for: groupId)
            }
        } else {
            // If no specific group ID, update all groups
            Task {
                await updateAllGroupBalances()
            }
        }
    }
    
    @MainActor
    func loadGroups() async {
        guard let currentUser = currentUser else { return }
        
        // Skip for dev mode since we don't have real Firebase data
        if useDevMode {
            isLoading = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        var loadedGroups: [Group] = []
        
        for groupId in currentUser.groupIds {
            do {
                let group = try await groupService.getGroupInfo(groupID: groupId)
                loadedGroups.append(group)
            } catch let error as NSError {
                if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                    // If we hit a permissions error, show the user a helpful message
                    errorMessage = """
                    Firestore permissions error.
                    
                    You need to set up Firestore security rules. Please:
                    1. Go to Firebase Console -> Firestore Database
                    2. Go to the Rules tab
                    3. Replace rules with the content from the firestore.rules.dev file for development
                    4. Publish the rules
                    
                    For development, you can use permissive rules. Make sure to use proper rules in production.
                    """
                    print("Firestore permissions error loading group \(groupId): \(error)")
                    return
                } else if error.domain == "GroupService" && error.code == 403 {
                    // Access control error - user not a member of the group
                    print("Access denied to group \(groupId): \(error.localizedDescription)")
                    // Skip this group - don't add to loadedGroups
                    continue
                } else if error.domain == "GroupService" && error.code == 401 {
                    // Authentication error
                    errorMessage = "Authentication required: \(error.localizedDescription)"
                    print("Authentication error loading group \(groupId): \(error)")
                    return
                } else {
                    print("Error loading group \(groupId): \(error)")
                }
            }
        }
        
        groups = loadedGroups.sorted(by: { $0.name < $1.name })
        
        if groups.count > 0 && _selectedGroup == nil {
            print("GroupViewModel.loadGroups: Setting initial group to \(groups.first?.name ?? "nil")")
            _selectedGroup = groups.first
        }
    }
    
    @MainActor
    func createGroup() async {
        guard !newGroupName.isEmpty else {
            errorMessage = "Group name cannot be empty"
            return
        }
        
        // Handle dev mode - create mock group
        if useDevMode {
            let groupId = "dev-group-\(UUID().uuidString)"
            let timestamp = Timestamp()
            let mockGroup = Group(
                id: groupId,
                name: newGroupName,
                memberIds: [currentUser?.uid ?? "dev-user"],
                createdBy: currentUser?.uid ?? "dev-user",
                createdAt: timestamp,
                settings: Settings(name: newGroupDescription.isEmpty ? "" : newGroupDescription),
                settled: false,
                settledAt: nil
            )
            
            // Add to our array
            groups.append(mockGroup)
            
            // Sort the groups
            groups.sort { $0.name < $1.name }
            
            // Select the new group
            selectedGroup = mockGroup
            
            // Reset form fields
            resetFormFields()
            
            // Navigate back
            appNavigationRef?.navigateBack()
            return
        }
        
        do {
            let group = try await groupService.createGroup(
                groupName: newGroupName, 
                groupDescription: newGroupDescription.isEmpty ? nil : newGroupDescription
            )
            
            // Update the current user's groupIds to include the new group
            if var user = currentUser {
                user.groupIds.append(group.id)
                currentUser = user
            }
            
            // Add the new group to our array
            groups.append(group)
            
            // Sort the groups by name
            groups.sort { $0.name < $1.name }
            
            // Select the new group
            selectedGroup = group
            
            // Reset form fields
            resetFormFields()
            
            // Navigate back
            appNavigationRef?.navigateBack()
        } catch let error as NSError {
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                errorMessage = """
                Firestore permissions error.
                
                You need to set up Firestore security rules. Please:
                1. Go to Firebase Console -> Firestore Database
                2. Go to the Rules tab
                3. Replace rules with the content from the firestore.rules.dev file for development
                4. Publish the rules
                
                For development, you can use permissive rules. Make sure to use proper rules in production.
                """
            } else if error.domain == "GroupService" && error.code == 403 {
                // Access control error
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                // Authentication error
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to create group: \(error.localizedDescription)"
            }
            print("Error creating group: \(error)")
        }
    }
    
    @MainActor
    func joinGroup() async {
        guard !joinGroupCode.isEmpty else {
            errorMessage = "Group code cannot be empty"
            return
        }
        
        // Handle dev mode
        if useDevMode {
            // Mock joining a group
            let groupId = joinGroupCode
            let timestamp = Timestamp()
            let mockGroup = Group(
                id: groupId,
                name: "Joined Group \(joinGroupCode)",
                memberIds: [currentUser?.uid ?? "dev-user"],
                createdBy: "dev-creator",
                createdAt: timestamp,
                settings: Settings(name: "Joined via code"),
                settled: false,
                settledAt: nil
            )
            
            // Add to our array if not already present
            if !groups.contains(where: { $0.id == groupId }) {
                groups.append(mockGroup)
                
                // Sort the groups
                groups.sort { $0.name < $1.name }
                
                // Select the new group
                selectedGroup = mockGroup
            } else {
                // Group already exists, just select it
                selectedGroup = groups.first(where: { $0.id == groupId })
            }
            
            // Reset form fields
            joinGroupCode = ""
            
            // Navigate back
            appNavigationRef?.navigateBack()
            return
        }
        
        do {
            let group = try await groupService.joinGroupByCode(code: joinGroupCode)
            
            // Update the current user's groupIds to include the new group
            if var user = currentUser, !user.groupIds.contains(group.id) {
                user.groupIds.append(group.id)
                currentUser = user
            }
            
            // Add the group to our array if not already present
            if !groups.contains(where: { $0.id == group.id }) {
                groups.append(group)
                
                // Sort the groups
                groups.sort { $0.name < $1.name }
                
                // Select the new group
                selectedGroup = group
            } else {
                // Group already exists, just select it
                selectedGroup = groups.first(where: { $0.id == group.id })
            }
            
            // Reset form field
            joinGroupCode = ""
            
            // Navigate back
            appNavigationRef?.navigateBack()
        } catch let error as NSError {
            if error.domain == "GroupService" && error.code == 404 {
                errorMessage = "Invalid group code or group not found."
            } else if error.domain == "GroupService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to join group: \(error.localizedDescription)"
            }
            print("Error joining group: \(error)")
        }
    }
    
    @MainActor
    func leaveCurrentGroup() async {
        guard let group = selectedGroup else { return }
        
        // Handle dev mode
        if useDevMode {
            // Update the current user's groupIds to remove the left group
            if var user = currentUser {
                user.groupIds.removeAll(where: { $0 == group.id })
                currentUser = user
            }
            
            // Remove from our array
            groups.removeAll(where: { $0.id == group.id })
            
            // Update selection
            if groups.isEmpty {
                selectedGroup = nil
            } else {
                selectedGroup = groups.first
            }
            return
        }
        
        do {
            try await groupService.leaveGroup(groupID: group.id)
            
            // Update the current user's groupIds to remove the left group
            if var user = currentUser {
                user.groupIds.removeAll(where: { $0 == group.id })
                currentUser = user
            }
            
            // Remove from our array
            groups.removeAll(where: { $0.id == group.id })
            
            // Update selection
            if groups.isEmpty {
                selectedGroup = nil
            } else {
                selectedGroup = groups.first
            }
        } catch let error as NSError {
            if error.domain == "GroupService" && error.code == 400 {
                // Special case for group creators - we should offer to delete the group instead
                errorMessage = "As the group creator, you can't leave the group. You can delete the group instead."
            } else if error.domain == "GroupService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to leave group: \(error.localizedDescription)"
            }
            print("Error leaving group: \(error)")
        }
    }
    
    @MainActor
    func deleteCurrentGroup() async {
        guard let group = selectedGroup else { return }
        
        // Handle dev mode
        if useDevMode {
            // Update the current user's groupIds to remove the deleted group
            if var user = currentUser {
                user.groupIds.removeAll(where: { $0 == group.id })
                currentUser = user
            }
            
            // Remove from our array
            groups.removeAll(where: { $0.id == group.id })
            
            // Update selection
            if groups.isEmpty {
                selectedGroup = nil
            } else {
                selectedGroup = groups.first
            }
            return
        }
        
        do {
            try await groupService.deleteGroup(groupID: group.id)
            
            // Update the current user's groupIds to remove the deleted group
            if var user = currentUser {
                user.groupIds.removeAll(where: { $0 == group.id })
                currentUser = user
            }
            
            // Remove from our array
            groups.removeAll(where: { $0.id == group.id })
            
            // Update selection
            if groups.isEmpty {
                selectedGroup = nil
            } else {
                selectedGroup = groups.first
            }
        } catch let error as NSError {
            if error.domain == "GroupService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to delete group: \(error.localizedDescription)"
            }
            print("Error deleting group: \(error)")
        }
    }
    
    private func resetFormFields() {
        newGroupName = ""
        newGroupDescription = ""
        joinGroupCode = ""
    }
    
    // Navigation helper methods for ViewModels that don't use AppNavigation
    func navigateToCreateGroup() {
        appNavigationRef?.showCreateGroupForm()
    }
    
    func navigateToJoinGroup() {
        appNavigationRef?.showJoinGroupForm()
    }
    
    func navigateToManageGroup(for group: Group) {
        appNavigationRef?.showManageGroupForm(for: group)
    }
    
    // MARK: - Balance Calculation
    
    // Track whether all expenses in a group are settled
    @Published var groupsWithAllExpensesSettled: [String: Bool] = [:]
    
    /// Calculate the current user's balance in a group (positive means they are owed money, negative means they owe)
    /// - Parameter groupId: The ID of the group to calculate balance for
    /// - Returns: The user's balance in the group (or nil if there's an error)
    @MainActor
    func calculateUserBalance(for groupId: String) async -> Double? {
        guard let currentUser = currentUser else { return nil }
        
        // Skip for dev mode - return mock data
        if useDevMode {
            // Generate a random balance for testing (between -100 and 100)
            let mockBalance = Double.random(in: -100...100)
            groupBalances[groupId] = mockBalance
            
            // Generate a random settled status for testing
            groupsWithAllExpensesSettled[groupId] = Bool.random()
            
            return mockBalance
        }
        
        do {
            // Get all expenses for the group
            let expenses = try await getExpensesForGroup(groupId: groupId)
            
            // Check if there are any unsettled expenses
            let hasUnsettledExpenses = expenses.contains { !$0.settled }
            
            // Store whether all expenses are settled
            groupsWithAllExpensesSettled[groupId] = !hasUnsettledExpenses
            
            // Skip settled expenses for balance calculation
            let activeExpenses = expenses.filter { !$0.settled }
            
            var balance: Double = 0.0
            
            for expense in activeExpenses {
                // Calculate how much the user paid vs. their share of the expense
                let userPaid = (expense.createdBy == currentUser.uid) ? expense.amount : 0
                let userShare = expense.splits[currentUser.uid] ?? 0
                
                // Add to balance (positive means they are owed, negative means they owe)
                balance += userPaid - userShare
            }
            
            // Update the stored balance
            groupBalances[groupId] = balance
            
            return balance
        } catch {
            print("Error calculating balance for group \(groupId): \(error)")
            return nil
        }
    }
    
    /// Get all expenses for a group
    /// - Parameter groupId: The ID of the group
    /// - Returns: Array of expenses
    private func getExpensesForGroup(groupId: String) async throws -> [Expense] {
        let expenseService = ExpenseService()
        return try await expenseService.getExpensesForGroup(groupId: groupId)
    }
    
    /// Update balances for all groups
    @MainActor
    func updateAllGroupBalances() async {
        for group in groups {
            _ = await calculateUserBalance(for: group.id)
        }
    }
    
    @MainActor
    func settleCurrentGroup() async {
        guard let group = selectedGroup else { return }
        
        // Handle dev mode
        if useDevMode {
            // In dev mode, just mark all expenses as settled
            // This would be done on the server in a real implementation
            return
        }
        
        do {
            try await groupService.settleGroup(groupID: group.id)
            
            // After settling all expenses, tell ExpenseViewModel to refresh
            NotificationCenter.default.post(name: NSNotification.Name("RefreshExpensesNotification"), object: nil)
            
            // Also notify about expense changes for balance updates
            NotificationCenter.default.post(name: NSNotification.Name("ExpenseChangedNotification"), object: nil, userInfo: ["groupId": group.id])
            
        } catch let error as NSError {
            if error.domain == "GroupService" && error.code == 400 {
                errorMessage = "No unsettled expenses to settle"
            } else if error.domain == "GroupService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to settle expenses: \(error.localizedDescription)"
            }
            print("Error settling expenses: \(error)")
        }
    }
    
    @MainActor
    func unsettleCurrentGroup() async {
        guard let group = selectedGroup else { return }
        
        // Check if the group is already unsettled
        guard group.settled else {
            errorMessage = "This group is already unsettled"
            return
        }
        
        // Handle dev mode
        if useDevMode {
            // Update in our array
            if let index = groups.firstIndex(where: { $0.id == group.id }) {
                var updatedGroup = group
                updatedGroup.settled = false
                updatedGroup.settledAt = nil
                groups[index] = updatedGroup
                selectedGroup = updatedGroup
            }
            return
        }
        
        do {
            try await groupService.unsettleGroup(groupID: group.id)
            
            // Update in our array
            if let index = groups.firstIndex(where: { $0.id == group.id }) {
                var updatedGroup = group
                updatedGroup.settled = false
                updatedGroup.settledAt = nil
                groups[index] = updatedGroup
                selectedGroup = updatedGroup
            }
        } catch let error as NSError {
            if error.domain == "GroupService" && error.code == 400 {
                errorMessage = "This group is already unsettled"
            } else if error.domain == "GroupService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to unsettle group: \(error.localizedDescription)"
            }
            print("Error unsettling group: \(error)")
        }
    }
    
    // We no longer need a separate update method as we access the properties directly
}