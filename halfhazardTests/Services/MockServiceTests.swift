//
//  MockServiceTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-25.
//

import XCTest
import FirebaseFirestore
@testable import halfhazard

/**
 * Tests for the mock service implementations.
 */
final class MockServiceTests: XCTestCase {
    
    // Mock services
    var mockUserService: MockUserService!
    var mockGroupService: MockGroupService!
    var mockExpenseService: MockExpenseService!
    
    // Test data
    var testUser: halfhazard.User!
    var testGroup: Group!
    var testExpense: Expense!
    
    override func setUp() async throws {
        // Set up mock services
        mockUserService = MockUserService()
        mockGroupService = MockGroupService()
        mockExpenseService = MockExpenseService()
        
        // Create test data
        testUser = halfhazard.User(
            uid: "mock-user-id",
            displayName: "Mock User",
            email: "mock@example.com",
            groupIds: ["mock-group-id"],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        testGroup = Group(
            id: "mock-group-id",
            name: "Mock Group",
            memberIds: ["mock-user-id"],
            createdBy: "mock-user-id",
            createdAt: Timestamp(),
            settings: Settings(name: "Mock Group Description")
        )
        
        testExpense = Expense(
            id: "mock-expense-id",
            amount: 100.0,
            description: "Mock Expense",
            groupId: "mock-group-id",
            createdBy: "mock-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["mock-user-id": 100.0]
        )
        
        // Add test data to mock services
        mockUserService.mockUsers = [testUser]
        mockUserService.mockCurrentUser = testUser
        mockGroupService.mockGroups = [testGroup]
        mockExpenseService.mockExpenses = [testExpense]
    }
    
    override func tearDown() async throws {
        mockUserService = nil
        mockGroupService = nil
        mockExpenseService = nil
        testUser = nil
        testGroup = nil
        testExpense = nil
    }
    
    // MARK: - User Service Tests
    
    func testUserService_GetCurrentUser() async throws {
        // Test that getCurrentUser returns the mock current user
        let currentUser = try await mockUserService.getCurrentUser()
        XCTAssertNotNil(currentUser)
        if let currentUser = currentUser {
            XCTAssertEqual(currentUser.uid, "mock-user-id")
        }
    }
    
    func testUserService_SignIn() async throws {
        // Test signing in with an existing user
        let signedInUser = try await mockUserService.signIn(email: "mock@example.com", password: "anypassword")
        XCTAssertEqual(signedInUser.uid, "mock-user-id")
        
        // Test signing in with a new user (should create one)
        let newUser = try await mockUserService.signIn(email: "new@example.com", password: "anypassword")
        XCTAssertNotNil(newUser)
        XCTAssertEqual(newUser.email, "new@example.com")
        
        // Verify that the new user was added to mock users
        XCTAssertEqual(mockUserService.mockUsers.count, 2)
    }
    
    func testUserService_CreateUser() async throws {
        // Test creating a new user
        let newUser = try await mockUserService.createUser(
            email: "created@example.com",
            password: "anypassword",
            displayName: "Created User"
        )
        
        // Verify that the user was created with correct properties
        XCTAssertEqual(newUser.email, "created@example.com")
        XCTAssertNotNil(newUser.displayName)
        if let displayName = newUser.displayName {
            XCTAssertEqual(displayName, "Created User")
        }
        
        // Verify that the user was added to mock users
        XCTAssertEqual(mockUserService.mockUsers.count, 2)
        XCTAssertTrue(mockUserService.mockUsers.contains(where: { $0.email == "created@example.com" }))
    }
    
    // MARK: - Group Service Tests
    
    func testGroupService_CreateGroup() async throws {
        // Test creating a group
        let newGroup = try await mockGroupService.createGroup(
            groupName: "New Mock Group",
            groupDescription: "New Mock Description"
        )
        
        // Verify the group was created with correct properties
        XCTAssertEqual(newGroup.name, "New Mock Group")
        XCTAssertEqual(newGroup.settings.name, "New Mock Description")
        
        // Verify that the group was added to mock groups
        XCTAssertEqual(mockGroupService.mockGroups.count, 2)
    }
    
    func testGroupService_JoinGroup() async throws {
        // Test joining a group
        let joinedGroup = try await mockGroupService.joinGroupByCode(code: "join-mock-group")
        
        // Verify the joined group has the right properties
        XCTAssertEqual(joinedGroup.id, "join-mock-group")
        
        // Verify that the group was added to mock groups
        XCTAssertEqual(mockGroupService.mockGroups.count, 2)
    }
    
    func testGroupService_GetGroupInfo() async throws {
        // Test getting group info for an existing group
        let group = try await mockGroupService.getGroupInfo(groupID: "mock-group-id")
        XCTAssertEqual(group.id, "mock-group-id")
        
        // Test getting group info for a non-existent group (should throw)
        do {
            _ = try await mockGroupService.getGroupInfo(groupID: "nonexistent-group")
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }
    }
    
    // MARK: - Expense Service Tests
    
    func testExpenseService_GetExpensesForGroup() async throws {
        // Add another expense in a different group
        let otherGroupExpense = Expense(
            id: "other-group-expense",
            amount: 50.0,
            description: "Expense in Other Group",
            groupId: "other-group-id",
            createdBy: "mock-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["mock-user-id": 50.0]
        )
        mockExpenseService.mockExpenses.append(otherGroupExpense)
        
        // Test getting expenses for a specific group
        let groupExpenses = try await mockExpenseService.getExpensesForGroup(groupId: "mock-group-id")
        XCTAssertEqual(groupExpenses.count, 1)
        XCTAssertEqual(groupExpenses[0].id, "mock-expense-id")
        
        // Test getting expenses for the other group
        let otherGroupExpenses = try await mockExpenseService.getExpensesForGroup(groupId: "other-group-id")
        XCTAssertEqual(otherGroupExpenses.count, 1)
        XCTAssertEqual(otherGroupExpenses[0].id, "other-group-expense")
    }
    
    func testExpenseService_UpdateExpense() async throws {
        // Make a copy of the original expense
        guard let originalExpense = testExpense else {
            XCTFail("Test expense should not be nil")
            return
        }
        
        var updatedExpense = originalExpense
        
        // Modify the expense
        updatedExpense.amount = 200.0
        updatedExpense.description = "Updated Mock Expense"
        
        // Call the update method
        try await mockExpenseService.updateExpense(updatedExpense)
        
        // Verify the expense was updated
        let expense = try await mockExpenseService.getExpense(expenseId: "mock-expense-id")
        XCTAssertEqual(expense.amount, 200.0)
        if let description = expense.description {
            XCTAssertEqual(description, "Updated Mock Expense")
        } else {
            XCTFail("Expense description should not be nil")
        }
    }
    
    func testExpenseService_DeleteExpense() async throws {
        // Verify initial state
        XCTAssertEqual(mockExpenseService.mockExpenses.count, 1)
        
        // Delete the expense
        try await mockExpenseService.deleteExpense(expenseId: "mock-expense-id")
        
        // Verify the expense was removed
        XCTAssertEqual(mockExpenseService.mockExpenses.count, 0)
        
        // Verify that getting the deleted expense throws an error
        do {
            _ = try await mockExpenseService.getExpense(expenseId: "mock-expense-id")
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }
    }
}