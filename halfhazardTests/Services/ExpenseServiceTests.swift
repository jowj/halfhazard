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
            settings: Settings(name: "Test Group Description"),
            settled: false,
            settledAt: nil
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
            splits: ["test-user-id": 50.0, "other-user-id": 50.0],
            settled: false,
            settledAt: nil
        )
        let expense2 = Expense(
            id: "expense2-id",
            amount: 200.0,
            description: "Expense 2",
            groupId: "test-group-id",
            createdBy: "other-user-id",
            createdAt: Timestamp(),
            splitType: .percentage,
            splits: ["test-user-id": 100.0, "other-user-id": 100.0],
            settled: false,
            settledAt: nil
        )
        let expense3 = Expense(
            id: "expense3-id",
            amount: 150.0,
            description: "Expense 3",
            groupId: "other-group-id", // Different group
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 75.0, "other-user-id": 75.0],
            settled: false,
            settledAt: nil
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
            splits: ["test-user-id": 50.0, "other-user-id": 50.0],
            settled: false,
            settledAt: nil
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
            splits: ["test-user-id": 50.0, "other-user-id": 50.0],
            settled: false,
            settledAt: nil
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
            splits: ["test-user-id": 50.0, "other-user-id": 50.0],
            settled: false,
            settledAt: nil
        )
        let expense2 = Expense(
            id: "expense2-id",
            amount: 200.0,
            description: "Expense 2",
            groupId: "test-group-id",
            createdBy: "other-user-id",
            createdAt: Timestamp(),
            splitType: .percentage,
            splits: ["test-user-id": 100.0, "other-user-id": 100.0],
            settled: false,
            settledAt: nil
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
    
    func testSettleExpense() async throws {
        // Create a test expense
        let expense = Expense(
            id: "test-expense-id",
            amount: 100.0,
            description: "Test Expense",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0],
            settled: false,
            settledAt: nil
        )
        expenseService.mockExpenses = [expense]
        
        // Settle the expense
        try await expenseService.settleExpense(expenseId: "test-expense-id")
        
        // Verify the expense was settled
        XCTAssertEqual(expenseService.mockExpenses.count, 1)
        XCTAssertTrue(expenseService.mockExpenses[0].settled)
        XCTAssertNotNil(expenseService.mockExpenses[0].settledAt)
    }
    
    func testSettleExpenseAlreadySettled() async throws {
        // Create a test expense that is already settled
        let timestamp = Timestamp()
        let expense = Expense(
            id: "test-expense-id",
            amount: 100.0,
            description: "Test Expense",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0],
            settled: true,
            settledAt: timestamp
        )
        expenseService.mockExpenses = [expense]
        
        // Try to settle the expense
        do {
            try await expenseService.settleExpense(expenseId: "test-expense-id")
            XCTFail("Expected an error when settling an already settled expense")
        } catch let error as NSError {
            // Verify we got the expected error
            XCTAssertEqual(error.domain, "ExpenseService")
            XCTAssertEqual(error.code, 400)
            XCTAssertTrue(error.localizedDescription.contains("already settled"))
        }
        
        // Verify the expense is still settled and the timestamp hasn't changed
        XCTAssertEqual(expenseService.mockExpenses.count, 1)
        XCTAssertTrue(expenseService.mockExpenses[0].settled)
        XCTAssertEqual(expenseService.mockExpenses[0].settledAt, timestamp)
    }
    
    func testUnsettleExpense() async throws {
        // Create a test expense that is already settled
        let expense = Expense(
            id: "test-expense-id",
            amount: 100.0,
            description: "Test Expense",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0],
            settled: true,
            settledAt: Timestamp()
        )
        expenseService.mockExpenses = [expense]
        
        // Unsettle the expense
        try await expenseService.unsettleExpense(expenseId: "test-expense-id")
        
        // Verify the expense was unsettled
        XCTAssertEqual(expenseService.mockExpenses.count, 1)
        XCTAssertFalse(expenseService.mockExpenses[0].settled)
        XCTAssertNil(expenseService.mockExpenses[0].settledAt)
    }
    
    func testUnsettleExpenseAlreadyUnsettled() async throws {
        // Create a test expense that is already unsettled
        let expense = Expense(
            id: "test-expense-id",
            amount: 100.0,
            description: "Test Expense",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0],
            settled: false,
            settledAt: nil
        )
        expenseService.mockExpenses = [expense]
        
        // Try to unsettle the expense
        do {
            try await expenseService.unsettleExpense(expenseId: "test-expense-id")
            XCTFail("Expected an error when unsettling an already unsettled expense")
        } catch let error as NSError {
            // Verify we got the expected error
            XCTAssertEqual(error.domain, "ExpenseService")
            XCTAssertEqual(error.code, 400)
            XCTAssertTrue(error.localizedDescription.contains("already unsettled"))
        }
        
        // Verify the expense is still unsettled
        XCTAssertEqual(expenseService.mockExpenses.count, 1)
        XCTAssertFalse(expenseService.mockExpenses[0].settled)
        XCTAssertNil(expenseService.mockExpenses[0].settledAt)
    }
    
    func testGetUnsettledExpensesForGroup() async throws {
        // Create test expenses with different settled states
        let unsettledExpense1 = Expense(
            id: "unsettled1-id",
            amount: 100.0,
            description: "Unsettled Expense 1",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0],
            settled: false,
            settledAt: nil
        )
        let unsettledExpense2 = Expense(
            id: "unsettled2-id",
            amount: 150.0,
            description: "Unsettled Expense 2",
            groupId: "test-group-id",
            createdBy: "other-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 75.0, "other-user-id": 75.0],
            settled: false,
            settledAt: nil
        )
        let settledExpense = Expense(
            id: "settled-id",
            amount: 200.0,
            description: "Settled Expense",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 100.0, "other-user-id": 100.0],
            settled: true,
            settledAt: Timestamp()
        )
        let unsettledExpenseOtherGroup = Expense(
            id: "unsettled-other-group-id",
            amount: 120.0,
            description: "Unsettled Expense Other Group",
            groupId: "other-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 60.0, "other-user-id": 60.0],
            settled: false,
            settledAt: nil
        )
        
        expenseService.mockExpenses = [
            unsettledExpense1,
            unsettledExpense2,
            settledExpense,
            unsettledExpenseOtherGroup
        ]
        
        // Test getting unsettled expenses for a specific group
        let unsettledExpenses = try await expenseService.getUnsettledExpensesForGroup(groupId: "test-group-id")
        
        // Verify only unsettled expenses for the specified group were returned
        XCTAssertEqual(unsettledExpenses.count, 2)
        XCTAssertTrue(unsettledExpenses.contains { $0.id == "unsettled1-id" })
        XCTAssertTrue(unsettledExpenses.contains { $0.id == "unsettled2-id" })
        XCTAssertFalse(unsettledExpenses.contains { $0.id == "settled-id" })
        XCTAssertFalse(unsettledExpenses.contains { $0.id == "unsettled-other-group-id" })
    }
}