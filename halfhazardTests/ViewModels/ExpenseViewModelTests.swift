//
//  ExpenseViewModelTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-24.
//

import XCTest
import FirebaseFirestore
import FirebaseAuth
@testable import halfhazard

@MainActor
final class ExpenseViewModelTests: XCTestCase {
    
    var viewModel: ExpenseViewModel!
    var mockExpenseService: MockExpenseService!
    var mockGroupService: MockGroupService!
    var testUser: halfhazard.User!
    var testGroup: Group!
    
    override func setUp() async throws {
        // Create a test user
        testUser = halfhazard.User(
            uid: "test-user-id",
            displayName: "Test User",
            email: "test@example.com",
            groupIds: ["test-group-id"],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        // Create a test group
        testGroup = Group(
            id: "test-group-id",
            name: "Test Group",
            memberIds: ["test-user-id", "other-user-id"],
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Group Description")
        )
        
        // Create the mock services
        mockExpenseService = MockExpenseService()
        mockGroupService = MockGroupService()
        mockGroupService.mockGroups = [testGroup]
        mockGroupService.mockGroupInfo = testGroup
        
        // Setup the view model with our test user and group in dev mode
        viewModel = ExpenseViewModel(
            currentUser: testUser,
            currentGroupId: testGroup.id,
            useDevMode: true
        )
        
        // Prepare some test expenses
        let expense1 = Expense(
            id: "expense1",
            amount: 100.0,
            description: "Expense One",
            groupId: "test-group-id",
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["test-user-id": 50.0, "other-user-id": 50.0]
        )
        
        let expense2 = Expense(
            id: "expense2",
            amount: 200.0,
            description: "Expense Two",
            groupId: "test-group-id",
            createdBy: "other-user-id",
            createdAt: Timestamp(),
            splitType: .custom,
            splits: ["test-user-id": 100.0, "other-user-id": 100.0]
        )
        
        mockExpenseService.mockExpenses = [expense1, expense2]
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockExpenseService = nil
        mockGroupService = nil
        testUser = nil
        testGroup = nil
    }
    
    func testLoadExpenses() async throws {
        // Load the expenses
        await viewModel.loadExpenses(forGroupId: "test-group-id")
        
        // In dev mode, mockExpenses are created with fixed data
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertGreaterThan(viewModel.expenses.count, 0)
    }
    
    func testCreateExpense() async throws {
        // Set form values
        viewModel.newExpenseAmount = 150.0
        viewModel.newExpenseDescription = "New Test Expense"
        viewModel.newExpenseSplitType = .equal
        viewModel.newExpenseSplits = ["test-user-id": 75.0, "other-user-id": 75.0]
        
        // Record initial count
        let initialCount = viewModel.expenses.count
        
        // Create the expense
        await viewModel.createExpense()
        
        // Check that the expense was created and added
        XCTAssertEqual(viewModel.expenses.count, initialCount + 1)
        
        // Find the created expense (it should be at index 0 since expenses are sorted by creation time)
        let newExpense = viewModel.expenses[0]
        
        // Check its properties
        XCTAssertEqual(newExpense.amount, 150.0)
        XCTAssertEqual(newExpense.description, "New Test Expense")
        XCTAssertEqual(newExpense.splitType, .equal)
        XCTAssertEqual(newExpense.groupId, "test-group-id")
        XCTAssertEqual(newExpense.createdBy, "test-user-id")
        
        // Check that the form was reset
        XCTAssertEqual(viewModel.newExpenseAmount, 0)
        XCTAssertEqual(viewModel.newExpenseDescription, "")
        XCTAssertEqual(viewModel.newExpenseSplitType, .equal)
        XCTAssertTrue(viewModel.newExpenseSplits.isEmpty)
        XCTAssertFalse(viewModel.showingCreateExpenseSheet)
    }
    
    func testDeleteExpense() async throws {
        // First load the expenses so we have some data
        await viewModel.loadExpenses(forGroupId: "test-group-id")
        
        // Add mock expenses to the view model directly
        viewModel.expenses = [
            Expense(
                id: "test-expense",
                amount: 100.0,
                description: "Test Expense",
                groupId: "test-group-id",
                createdBy: "test-user-id",
                createdAt: Timestamp(),
                splitType: .equal,
                splits: ["test-user-id": 50.0, "other-user-id": 50.0]
            )
        ]
        
        // Record initial count
        XCTAssertEqual(viewModel.expenses.count, 1)
        
        // Delete the expense
        await viewModel.deleteExpense(expense: viewModel.expenses[0])
        
        // Check that the expense was removed
        XCTAssertEqual(viewModel.expenses.count, 0)
    }
    
    func testSelectExpense() async throws {
        // Add mock expenses to the view model directly
        viewModel.expenses = [
            Expense(
                id: "test-expense",
                amount: 100.0,
                description: "Test Expense",
                groupId: "test-group-id",
                createdBy: "test-user-id",
                createdAt: Timestamp(),
                splitType: .equal,
                splits: ["test-user-id": 50.0, "other-user-id": 50.0]
            )
        ]
        
        // Initially no selection
        XCTAssertNil(viewModel.selectedExpense)
        XCTAssertFalse(viewModel.showingExpenseDetailSheet)
        
        // Select an expense
        viewModel.selectExpense(viewModel.expenses[0])
        
        // Check that the expense was selected
        XCTAssertNotNil(viewModel.selectedExpense)
        XCTAssertEqual(viewModel.selectedExpense?.id, "test-expense")
        XCTAssertTrue(viewModel.showingExpenseDetailSheet)
    }
    
    func testClearSelectedExpense() async throws {
        // Add mock expenses and select one
        viewModel.expenses = [
            Expense(
                id: "test-expense",
                amount: 100.0,
                description: "Test Expense",
                groupId: "test-group-id",
                createdBy: "test-user-id",
                createdAt: Timestamp(),
                splitType: .equal,
                splits: ["test-user-id": 50.0, "other-user-id": 50.0]
            )
        ]
        viewModel.selectExpense(viewModel.expenses[0])
        
        // Check that we have a selection
        XCTAssertNotNil(viewModel.selectedExpense)
        XCTAssertTrue(viewModel.showingExpenseDetailSheet)
        
        // Clear the selection
        viewModel.clearSelectedExpense()
        
        // Check that the selection was cleared
        XCTAssertNil(viewModel.selectedExpense)
        XCTAssertFalse(viewModel.showingExpenseDetailSheet)
    }
    
    func testPrepareExpenseForEditing() async throws {
        // Add mock expenses
        viewModel.expenses = [
            Expense(
                id: "test-expense",
                amount: 100.0,
                description: "Test Expense",
                groupId: "test-group-id",
                createdBy: "test-user-id",
                createdAt: Timestamp(),
                splitType: .equal,
                splits: ["test-user-id": 50.0, "other-user-id": 50.0]
            )
        ]
        
        // Prepare an expense for editing
        viewModel.prepareExpenseForEditing(viewModel.expenses[0])
        
        // Check that the expense was prepared for editing
        XCTAssertNotNil(viewModel.editingExpense)
        XCTAssertEqual(viewModel.editingExpense?.id, "test-expense")
        XCTAssertEqual(viewModel.newExpenseAmount, 100.0)
        XCTAssertEqual(viewModel.newExpenseDescription, "Test Expense")
        XCTAssertEqual(viewModel.newExpenseSplitType, .equal)
        XCTAssertEqual(viewModel.newExpenseSplits["test-user-id"], 50.0)
        XCTAssertEqual(viewModel.newExpenseSplits["other-user-id"], 50.0)
        XCTAssertTrue(viewModel.showingEditExpenseSheet)
    }
    
    func testSaveEditedExpense() async throws {
        // Add mock expenses and prepare one for editing
        viewModel.expenses = [
            Expense(
                id: "test-expense",
                amount: 100.0,
                description: "Test Expense",
                groupId: "test-group-id",
                createdBy: "test-user-id",
                createdAt: Timestamp(),
                splitType: .equal,
                splits: ["test-user-id": 50.0, "other-user-id": 50.0]
            )
        ]
        viewModel.prepareExpenseForEditing(viewModel.expenses[0])
        
        // Modify the form values
        viewModel.newExpenseAmount = 150.0
        viewModel.newExpenseDescription = "Updated Expense"
        viewModel.newExpenseSplitType = .custom
        viewModel.newExpenseSplits = ["test-user-id": 100.0, "other-user-id": 50.0]
        
        // Save the edited expense
        await viewModel.saveEditedExpense()
        
        // Check that the expense was updated
        XCTAssertEqual(viewModel.expenses[0].amount, 150.0)
        XCTAssertEqual(viewModel.expenses[0].description, "Updated Expense")
        XCTAssertEqual(viewModel.expenses[0].splitType, .custom)
        XCTAssertEqual(viewModel.expenses[0].splits["test-user-id"], 100.0)
        XCTAssertEqual(viewModel.expenses[0].splits["other-user-id"], 50.0)
        
        // Check that the form was reset and sheet closed
        XCTAssertNil(viewModel.editingExpense)
        XCTAssertEqual(viewModel.newExpenseAmount, 0)
        XCTAssertEqual(viewModel.newExpenseDescription, "")
        XCTAssertEqual(viewModel.newExpenseSplitType, .equal)
        XCTAssertTrue(viewModel.newExpenseSplits.isEmpty)
        XCTAssertFalse(viewModel.showingEditExpenseSheet)
    }
    
    func testUpdateContext() async throws {
        // Create a different user and group
        let newUser = halfhazard.User(
            uid: "new-user-id",
            displayName: "New User",
            email: "new@example.com",
            groupIds: ["new-group-id"],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        // Update the context
        viewModel.updateContext(user: newUser, groupId: "new-group-id", devMode: false)
        
        // Check that the context was updated
        XCTAssertEqual(viewModel.currentUser?.uid, "new-user-id")
        XCTAssertEqual(viewModel.currentGroupId, "new-group-id")
    }
}