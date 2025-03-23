//
//  ExpenseServiceTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-24.
//

import XCTest
import FirebaseFirestore
import FirebaseAuth
@testable import halfhazard

@MainActor
final class ExpenseServiceTests: XCTestCase {
    
    var expenseService: MockExpenseService!
    var userService: MockUserService!
    var groupService: MockGroupService!
    
    override func setUp() async throws {
        // Create a mock user to simulate being logged in
        userService = MockUserService()
        let testUser = halfhazard.User(
            uid: "test-user-id",
            displayName: "Test User",
            email: "test@example.com",
            groupIds: ["test-group-id"],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        userService.mockUsers = [testUser]
        userService.mockCurrentUser = testUser
        
        // Create a mock group that the user is a member of
        groupService = MockGroupService()
        let testGroup = Group(
            id: "test-group-id",
            name: "Test Group",
            memberIds: ["test-user-id", "other-user-id"],
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Group Description")
        )
        groupService.mockGroups = [testGroup]
        
        // Initialize the expense service with empty test data
        expenseService = MockExpenseService()
    }
    
    override func tearDown() async throws {
        // Clear all test data between tests
        expenseService.mockExpenses = []
        expenseService.mockError = nil
    }
    
    func testCreateExpense() async throws {
        // Test creating a new expense
        let expense = try await expenseService.createExpense(
            amount: 100.0,
            description: "Test Expense",
            groupId: "test-group-id",
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0]
        )
        
        // Verify expense was created with correct properties
        XCTAssertEqual(expense.amount, 100.0)
        XCTAssertEqual(expense.description, "Test Expense")
        XCTAssertEqual(expense.groupId, "test-group-id")
        XCTAssertEqual(expense.createdBy, "test-user-id")
        XCTAssertEqual(expense.splitType, .equal)
        XCTAssertEqual(expense.splits["test-user-id"], 50.0)
        XCTAssertEqual(expense.splits["other-user-id"], 50.0)
        XCTAssertNotNil(expense.id)
        
        // Verify expense was added to the mock storage
        XCTAssertEqual(expenseService.mockExpenses.count, 1)
    }
    
    func testGetExpensesForGroup() async throws {
        // Create some test expenses
        let expense1 = Expense(
            id: "expense1-id",
            amount: 100.0,
            description: "Expense 1",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0]
        )
        let expense2 = Expense(
            id: "expense2-id",
            amount: 200.0,
            description: "Expense 2",
            groupId: "test-group-id",
            createdBy: "other-user-id",
            createdAt: Timestamp(),
            splitType: .percentage,
            splits: ["test-user-id": 100.0, "other-user-id": 100.0]
        )
        let expense3 = Expense(
            id: "expense3-id",
            amount: 150.0,
            description: "Expense 3",
            groupId: "other-group-id", // Different group
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 75.0, "other-user-id": 75.0]
        )
        expenseService.mockExpenses = [expense1, expense2, expense3]
        
        // Test getting expenses for a specific group
        let expenses = try await expenseService.getExpensesForGroup(groupId: "test-group-id")
        
        // Verify only expenses for the specified group were returned
        XCTAssertEqual(expenses.count, 2)
        XCTAssertTrue(expenses.contains { $0.id == "expense1-id" })
        XCTAssertTrue(expenses.contains { $0.id == "expense2-id" })
        XCTAssertFalse(expenses.contains { $0.id == "expense3-id" })
    }
    
    func testUpdateExpense() async throws {
        // Create a test expense
        let expense = Expense(
            id: "test-expense-id",
            amount: 100.0,
            description: "Original Description",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0]
        )
        expenseService.mockExpenses = [expense]
        
        // Create an updated version of the expense
        var updatedExpense = expense
        updatedExpense.amount = 150.0
        updatedExpense.description = "Updated Description"
        updatedExpense.splitType = .percentage
        updatedExpense.splits = ["test-user-id": 100.0, "other-user-id": 50.0]
        
        // Test updating the expense
        try await expenseService.updateExpense(updatedExpense)
        
        // Verify the expense was updated in the mock storage
        XCTAssertEqual(expenseService.mockExpenses[0].amount, 150.0)
        XCTAssertEqual(expenseService.mockExpenses[0].description, "Updated Description")
        XCTAssertEqual(expenseService.mockExpenses[0].splitType, .percentage)
        XCTAssertEqual(expenseService.mockExpenses[0].splits["test-user-id"], 100.0)
        XCTAssertEqual(expenseService.mockExpenses[0].splits["other-user-id"], 50.0)
    }
    
    func testDeleteExpense() async throws {
        // Create a test expense
        let expense = Expense(
            id: "test-expense-id",
            amount: 100.0,
            description: "Test Expense",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0]
        )
        expenseService.mockExpenses = [expense]
        
        // Test deleting the expense
        try await expenseService.deleteExpense(expenseId: "test-expense-id")
        
        // Verify the expense was removed from the mock storage
        XCTAssertEqual(expenseService.mockExpenses.count, 0)
    }
    
    func testGetExpense() async throws {
        // Create some test expenses
        let expense1 = Expense(
            id: "expense1-id",
            amount: 100.0,
            description: "Expense 1",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0]
        )
        let expense2 = Expense(
            id: "expense2-id",
            amount: 200.0,
            description: "Expense 2",
            groupId: "test-group-id",
            createdBy: "other-user-id",
            createdAt: Timestamp(),
            splitType: .percentage,
            splits: ["test-user-id": 100.0, "other-user-id": 100.0]
        )
        expenseService.mockExpenses = [expense1, expense2]
        
        // Test getting a specific expense
        let retrievedExpense = try await expenseService.getExpense(expenseId: "expense2-id")
        
        // Verify the correct expense was retrieved
        XCTAssertEqual(retrievedExpense.id, "expense2-id")
        XCTAssertEqual(retrievedExpense.amount, 200.0)
        XCTAssertEqual(retrievedExpense.description, "Expense 2")
    }
    
    func testGetExpenseNotFound() async throws {
        // Test getting a non-existent expense
        do {
            _ = try await expenseService.getExpense(expenseId: "nonexistent-id")
            XCTFail("Expected an error to be thrown")
        } catch let error as NSError {
            // Verify the correct error was thrown
            XCTAssertEqual(error.domain, "ExpenseService")
            XCTAssertEqual(error.code, 404)
        }
    }
}