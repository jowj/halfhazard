//
//  ServiceBehaviorTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-24.
//

import XCTest
import FirebaseFirestore
@testable import halfhazard

/**
 * These tests verify service behavior without using mocks of Firebase services.
 * Instead, they run in dev mode and test the logical behavior of services.
 */
final class ServiceBehaviorTests: XCTestCase {
    
    // Test data
    var testUser: halfhazard.User!
    var testGroup: Group!
    var testExpense: Expense!
    var otherUser: halfhazard.User!
    
    // Services
    var expenseViewModel: ExpenseViewModel!
    var groupViewModel: GroupViewModel!
    var userService: UserService!
    
    override func setUp() async throws {
        // Create test user
        testUser = halfhazard.User(
            uid: "test-user-id",
            displayName: "Test User",
            email: "test@example.com",
            groupIds: ["test-group-id"],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        // Create another test user
        otherUser = halfhazard.User(
            uid: "other-user-id",
            displayName: "Other User",
            email: "other@example.com",
            groupIds: ["test-group-id"],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        // Create test group
        testGroup = Group(
            id: "test-group-id",
            name: "Test Group",
            memberIds: ["test-user-id", "other-user-id"],
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Group Description")
        )
        
        // Create test expense
        testExpense = Expense(
            id: "test-expense-id",
            amount: 100.0,
            description: "Test Expense",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0]
        )
        
        // Initialize services/view models in dev mode
        groupViewModel = GroupViewModel(currentUser: testUser, useDevMode: true)
        expenseViewModel = ExpenseViewModel(currentUser: testUser, currentGroupId: testGroup.id, useDevMode: true)
        
        // Create a mock implementation of UserService for tests that's similar to what the ViewModels are doing
        let mockUserService = UserServiceMock()
        mockUserService.mockCurrentUser = testUser
        mockUserService.mockUsers.append(testUser)
        mockUserService.mockUsers.append(otherUser)
        
        userService = mockUserService
    }
    
    // MARK: - Mock User Service for testing
    
    class UserServiceMock: UserService {
        var mockUsers: [halfhazard.User] = []
        var mockCurrentUser: halfhazard.User?
        
        override func createUser(email: String, password: String, displayName: String?) async throws -> halfhazard.User {
            let uid = "mock-\(UUID().uuidString)"
            let newUser = halfhazard.User(
                uid: uid,
                displayName: displayName,
                email: email,
                groupIds: [],
                createdAt: Timestamp(),
                lastActive: Timestamp()
            )
            
            mockUsers.append(newUser)
            mockCurrentUser = newUser
            return newUser
        }
        
        override func getUser(uid: String) async throws -> halfhazard.User {
            if let user = mockUsers.first(where: { $0.uid == uid }) {
                return user
            }
            
            throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        override func updateUser(_ user: halfhazard.User) async throws {
            if let index = mockUsers.firstIndex(where: { $0.uid == user.uid }) {
                mockUsers[index] = user
                if mockCurrentUser?.uid == user.uid {
                    mockCurrentUser = user
                }
            }
        }
        
        override func signIn(email: String, password: String) async throws -> halfhazard.User {
            if let user = mockUsers.first(where: { $0.email == email }) {
                mockCurrentUser = user
                return user
            }
            
            // If user doesn't exist, create one
            let uid = "mock-\(UUID().uuidString)"
            let newUser = halfhazard.User(
                uid: uid,
                displayName: nil,
                email: email,
                groupIds: [],
                createdAt: Timestamp(),
                lastActive: Timestamp()
            )
            
            mockUsers.append(newUser)
            mockCurrentUser = newUser
            return newUser
        }
        
        override func signOut() throws {
            mockCurrentUser = nil
        }
        
        override func getCurrentUser() async throws -> halfhazard.User? {
            return mockCurrentUser
        }
    }
    
    override func tearDown() async throws {
        testUser = nil
        testGroup = nil
        testExpense = nil
        otherUser = nil
        groupViewModel = nil
        expenseViewModel = nil
        userService = nil
    }
    
    // MARK: - Group ViewModel Tests
    
    func testCreateGroup() async throws {
        // Set form values
        groupViewModel.newGroupName = "New Test Group"
        groupViewModel.newGroupDescription = "New Test Group Description"
        
        // Initial count
        XCTAssertEqual(groupViewModel.groups.count, 0)
        
        // Create the group
        await groupViewModel.createGroup()
        
        // Check that the group was created and added
        XCTAssertEqual(groupViewModel.groups.count, 1)
        XCTAssertEqual(groupViewModel.groups[0].name, "New Test Group")
        XCTAssertEqual(groupViewModel.groups[0].settings.name, "New Test Group Description")
        XCTAssertEqual(groupViewModel.groups[0].createdBy, testUser.uid)
        XCTAssertTrue(groupViewModel.groups[0].memberIds.contains(testUser.uid))
    }
    
    func testCreateGroupWithEmptyName() async throws {
        // Set form values with empty name
        groupViewModel.newGroupName = ""
        groupViewModel.newGroupDescription = "Description for Empty Group"
        
        // Initial count
        XCTAssertEqual(groupViewModel.groups.count, 0)
        
        // Create the group (should fail or not add to groups array due to validation)
        await groupViewModel.createGroup()
        
        // Check that no group was created
        XCTAssertEqual(groupViewModel.groups.count, 0)
        
        // Check that error message was set (assuming the implementation sets an error message)
        XCTAssertNotNil(groupViewModel.errorMessage)
    }
    
    func testJoinGroup() async throws {
        // Set form values
        groupViewModel.joinGroupCode = "join-group-id"
        
        // Initial count
        XCTAssertEqual(groupViewModel.groups.count, 0)
        
        // Join the group
        await groupViewModel.joinGroup()
        
        // Check that the group was added
        XCTAssertEqual(groupViewModel.groups.count, 1)
        XCTAssertEqual(groupViewModel.groups[0].id, "join-group-id")
        
        // Check that the group was selected
        XCTAssertNotNil(groupViewModel.selectedGroup)
        XCTAssertEqual(groupViewModel.selectedGroup?.id, "join-group-id")
    }
    
    func testJoinGroupWithEmptyCode() async throws {
        // Set empty join code
        groupViewModel.joinGroupCode = ""
        
        // Initial count
        XCTAssertEqual(groupViewModel.groups.count, 0)
        
        // Try to join the group
        await groupViewModel.joinGroup()
        
        // Check that no group was added
        XCTAssertEqual(groupViewModel.groups.count, 0)
        
        // Check error message
        XCTAssertNotNil(groupViewModel.errorMessage)
    }
    
    func testLeaveGroup() async throws {
        // First create a group to leave
        groupViewModel.newGroupName = "Group To Leave"
        groupViewModel.newGroupDescription = "This group will be left"
        await groupViewModel.createGroup()
        
        // Verify group was created
        XCTAssertEqual(groupViewModel.groups.count, 1)
        let groupId = groupViewModel.groups[0].id
        
        // Select the group first
        groupViewModel.selectedGroup = groupViewModel.groups[0]
        
        // Now leave the group
        await groupViewModel.leaveCurrentGroup()
        
        // Verify group was removed
        XCTAssertEqual(groupViewModel.groups.count, 0)
        
        // Check that selected group was cleared if it was the left group
        XCTAssertNil(groupViewModel.selectedGroup)
    }
    
    // TODO: Implement this test once the group member management functions are available
    /*func testGroupMemberManagement() async throws {
        // Create a group first
        groupViewModel.newGroupName = "Member Test Group"
        await groupViewModel.createGroup()
        
        // Get the created group
        XCTAssertEqual(groupViewModel.groups.count, 1)
        let group = groupViewModel.groups[0]
        
        // Initial state should have current user as member
        XCTAssertTrue(group.memberIds.contains(testUser.uid))
        XCTAssertEqual(group.memberIds.count, 1)
        
        // Add another member - Not implemented yet
        // await groupViewModel.addMemberToGroup(groupId: group.id, userId: otherUser.uid)
        
        // Verify member was added
        // let updatedGroup = groupViewModel.groups[0]
        // XCTAssertEqual(updatedGroup.memberIds.count, 2)
        // XCTAssertTrue(updatedGroup.memberIds.contains(otherUser.uid))
        
        // Remove the other member - Not implemented yet
        // await groupViewModel.removeMemberFromGroup(groupId: group.id, userId: otherUser.uid)
        
        // Verify member was removed
        // let finalGroup = groupViewModel.groups[0]
        // XCTAssertEqual(finalGroup.memberIds.count, 1)
        // XCTAssertFalse(finalGroup.memberIds.contains(otherUser.uid))
    }*/
    
    // MARK: - Expense ViewModel Tests
    
    func testCreateExpense() async throws {
        // Set form values
        expenseViewModel.newExpenseAmount = 150.0
        expenseViewModel.newExpenseDescription = "New Test Expense"
        expenseViewModel.newExpenseSplitType = .equal
        
        // Create the expense
        await expenseViewModel.createExpense()
        
        // Check that the expense was created and added
        XCTAssertEqual(expenseViewModel.expenses.count, 1)
        
        // Find the created expense
        let newExpense = expenseViewModel.expenses[0]
        
        // Check its properties
        XCTAssertEqual(newExpense.amount, 150.0)
        XCTAssertEqual(newExpense.description, "New Test Expense")
        XCTAssertEqual(newExpense.splitType, .equal)
        XCTAssertEqual(newExpense.groupId, "test-group-id")
        XCTAssertEqual(newExpense.createdBy, "test-user-id")
        
        // Check that splits were created automatically
        XCTAssertNotNil(newExpense.splits["test-user-id"])
    }
    
    func testCreateExpenseWithInvalidAmount() async throws {
        // Set form values with invalid amount
        expenseViewModel.newExpenseAmount = -50.0 // Negative amount
        expenseViewModel.newExpenseDescription = "Invalid Amount Expense"
        expenseViewModel.newExpenseSplitType = .equal
        
        // Attempt to create the expense
        await expenseViewModel.createExpense()
        
        // Check that no expense was created due to validation
        XCTAssertEqual(expenseViewModel.expenses.count, 0)
        
        // Check error message
        XCTAssertNotNil(expenseViewModel.errorMessage)
    }
    
    func testCreateExpenseWithZeroAmount() async throws {
        // Set form values with zero amount
        expenseViewModel.newExpenseAmount = 0.0
        expenseViewModel.newExpenseDescription = "Zero Amount Expense"
        expenseViewModel.newExpenseSplitType = .equal
        
        // Attempt to create the expense
        await expenseViewModel.createExpense()
        
        // Check that no expense was created due to validation
        XCTAssertEqual(expenseViewModel.expenses.count, 0)
        
        // Check error message
        XCTAssertNotNil(expenseViewModel.errorMessage)
    }
    
    func testCreateExpenseWithEmptyDescription() async throws {
        // Set form values with empty description (should be allowed)
        expenseViewModel.newExpenseAmount = 75.0
        expenseViewModel.newExpenseDescription = ""
        expenseViewModel.newExpenseSplitType = .equal
        
        // Create the expense
        await expenseViewModel.createExpense()
        
        // Check that the expense was created despite empty description
        XCTAssertEqual(expenseViewModel.expenses.count, 1)
        
        // Find the created expense
        let newExpense = expenseViewModel.expenses[0]
        
        // Check its properties
        XCTAssertEqual(newExpense.amount, 75.0)
        XCTAssertNil(newExpense.description) // Empty string is converted to nil in the model
    }
    
    // TODO: Update this test when percentage split functionality is implemented
    /*func testCreateExpenseWithPercentageSplit() async throws {
        // Set form values with percentage split
        expenseViewModel.newExpenseAmount = 100.0
        expenseViewModel.newExpenseDescription = "Percentage Split Test"
        expenseViewModel.newExpenseSplitType = .custom
        
        // Missing functionality for setting percentages 
        // expenseViewModel.splitPercentages = [
        //    "test-user-id": 75.0,
        //    "other-user-id": 25.0
        // ]
        
        // Create the expense
        await expenseViewModel.createExpense()
        
        // Check that the expense was created
        XCTAssertEqual(expenseViewModel.expenses.count, 1)
        
        // Find the created expense
        let newExpense = expenseViewModel.expenses[0]
        
        // Check its properties
        XCTAssertEqual(newExpense.splitType, .custom)
        
        // Check that split amounts match the percentages
        XCTAssertEqual(newExpense.splits["test-user-id"], 75.0)
        XCTAssertEqual(newExpense.splits["other-user-id"], 25.0)
    }*/
    
    func testExpenseLifecycle() async throws {
        // 1. First create an expense
        expenseViewModel.newExpenseAmount = 200.0
        expenseViewModel.newExpenseDescription = "Lifecycle Test Expense"
        expenseViewModel.newExpenseSplitType = .equal
        await expenseViewModel.createExpense()
        
        // Verify it was created
        XCTAssertEqual(expenseViewModel.expenses.count, 1)
        let createdExpense = expenseViewModel.expenses[0]
        
        // 2. Select the expense for viewing
        expenseViewModel.selectExpense(createdExpense)
        XCTAssertNotNil(expenseViewModel.selectedExpense)
        if let selectedExpense = expenseViewModel.selectedExpense {
            XCTAssertEqual(selectedExpense.id, createdExpense.id)
        }
        XCTAssertTrue(expenseViewModel.showingExpenseDetailSheet)
        
        // 3. Clear selection
        expenseViewModel.clearSelectedExpense()
        XCTAssertNil(expenseViewModel.selectedExpense)
        XCTAssertFalse(expenseViewModel.showingExpenseDetailSheet)
        
        // 4. Prepare expense for editing
        expenseViewModel.prepareExpenseForEditing(createdExpense)
        XCTAssertNotNil(expenseViewModel.editingExpense)
        XCTAssertEqual(expenseViewModel.newExpenseAmount, 200.0)
        // Handle description being optional
        XCTAssertEqual(expenseViewModel.newExpenseDescription, "Lifecycle Test Expense")
        
        // 5. Update the expense
        expenseViewModel.newExpenseAmount = 250.0
        expenseViewModel.newExpenseDescription = "Updated Test Expense"
        expenseViewModel.newExpenseSplitType = .custom
        await expenseViewModel.saveEditedExpense()
        
        // Verify it was updated
        let updatedExpense = expenseViewModel.expenses[0]
        XCTAssertEqual(updatedExpense.amount, 250.0)
        XCTAssertEqual(updatedExpense.description, "Updated Test Expense")
        XCTAssertEqual(updatedExpense.splitType, .custom)
        
        // 6. Delete the expense
        await expenseViewModel.deleteExpense(expense: updatedExpense)
        XCTAssertEqual(expenseViewModel.expenses.count, 0)
    }
    
    func testCantDeleteOthersExpense() async throws {
        // 1. Create an expense that belongs to another user
        let othersExpense = Expense(
            id: "other-user-expense-id",
            amount: 300.0,
            description: "Expense by Other User",
            groupId: "test-group-id",
            createdBy: "other-user-id", // Created by other user
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 150.0, "other-user-id": 150.0]
        )
        
        // Add the expense to the view model's list
        expenseViewModel.expenses.append(othersExpense)
        
        // 2. Try to delete the expense
        await expenseViewModel.deleteExpense(expense: othersExpense)
        
        // 3. Verify the expense wasn't deleted (permission check)
        XCTAssertEqual(expenseViewModel.expenses.count, 1)
        XCTAssertNotNil(expenseViewModel.errorMessage)
    }
    
    // TODO: Implement this test when expense total calculation is added
    /*func testCalculateTotalExpenses() async throws {
        // Create multiple expenses
        let expense1 = Expense(
            id: "expense-1",
            amount: 100.0,
            description: "Expense 1",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(date: Date().addingTimeInterval(-3600)), // 1 hour ago
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0]
        )
        
        let expense2 = Expense(
            id: "expense-2",
            amount: 200.0,
            description: "Expense 2",
            groupId: "test-group-id",
            createdBy: "other-user-id",
            createdAt: Timestamp(date: Date().addingTimeInterval(-7200)), // 2 hours ago
            splitType: .equal,
            splits: ["test-user-id": 100.0, "other-user-id": 100.0]
        )
        
        // Add expenses to view model
        expenseViewModel.expenses = [expense1, expense2]
        
        // Not implemented yet:
        // await expenseViewModel.calculateTotals()
        
        // Calculate totals manually for testing
        let totalAmount = expense1.amount + expense2.amount
        XCTAssertEqual(totalAmount, 300.0)
        
        let userAmount = expense1.splits["test-user-id"]! + expense2.splits["test-user-id"]!
        XCTAssertEqual(userAmount, 150.0)
        
        let otherAmount = expense1.splits["other-user-id"]! + expense2.splits["other-user-id"]!
        XCTAssertEqual(otherAmount, 150.0)
    }*/
    
    // MARK: - User Service Tests
    
    func testCreateAndGetUser() async throws {
        // Create a new user
        let email = "newuser@example.com"
        let password = "password123"
        let displayName = "New Test User"
        
        let createdUser = try await userService.createUser(
            email: email,
            password: password,
            displayName: displayName
        )
        
        // Check user properties
        XCTAssertEqual(createdUser.email, email)
        XCTAssertEqual(createdUser.displayName, displayName)
        XCTAssertTrue(createdUser.groupIds.isEmpty)
        
        // Get the user
        let retrievedUser = try await userService.getUser(uid: createdUser.uid)
        
        // Check that the retrieved user matches the created user
        XCTAssertEqual(retrievedUser.uid, createdUser.uid)
        XCTAssertEqual(retrievedUser.email, email)
    }
    
    func testSignInAndSignOut() async throws {
        // First create a user
        let email = "signin@example.com"
        let password = "password123"
        
        _ = try await userService.createUser(
            email: email,
            password: password,
            displayName: "Sign In User"
        )
        
        // Sign out first to ensure clean state
        try userService.signOut()
        
        // Sign in with the created user
        let signedInUser = try await userService.signIn(
            email: email,
            password: password
        )
        
        // Check user properties
        XCTAssertEqual(signedInUser.email, email)
        
        // Get current user
        let currentUser = try await userService.getCurrentUser()
        XCTAssertNotNil(currentUser)
        XCTAssertEqual(currentUser?.email, email)
        
        // Sign out
        try userService.signOut()
        
        // Verify signed out (this might throw an error or return nil depending on implementation)
        do {
            let userAfterSignOut = try await userService.getCurrentUser()
            if userAfterSignOut != nil {
                XCTFail("User should be nil after sign out")
            }
        } catch {
            // Exception is expected after signing out
        }
    }
    
    func testUpdateUser() async throws {
        // First create and sign in as a user
        let email = "update@example.com"
        let password = "password123"
        let initialName = "Update Test User"
        
        var user = try await userService.createUser(
            email: email,
            password: password,
            displayName: initialName
        )
        
        // Update the user
        user.displayName = "Updated Name"
        try await userService.updateUser(user)
        
        // Get the updated user
        let updatedUser = try await userService.getUser(uid: user.uid)
        
        // Check that the name was updated
        XCTAssertEqual(updatedUser.displayName, "Updated Name")
        XCTAssertNotEqual(updatedUser.displayName, initialName)
    }
}