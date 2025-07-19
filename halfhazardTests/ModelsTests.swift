//
//  ModelsTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-24.
//

import XCTest
import FirebaseFirestore
@testable import halfhazard

final class ModelsTests: XCTestCase {
    
    func testUserModel() {
        // Create a user
        let user = halfhazard.User(
            uid: "test-uid",
            displayName: "Test User",
            email: "test@example.com",
            groupIds: ["group1", "group2"],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        // Test user properties
        XCTAssertEqual(user.uid, "test-uid")
        XCTAssertEqual(user.id, "test-uid") // id should match uid
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.groupIds, ["group1", "group2"])
    }
    
    func testUserModelWithEmptyValues() {
        // Create a user with minimal data
        let user = halfhazard.User(
            uid: "minimal-uid",
            displayName: nil,
            email: "minimal@example.com",
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        // Test user properties with empty values
        XCTAssertEqual(user.uid, "minimal-uid")
        XCTAssertNil(user.displayName)
        XCTAssertEqual(user.email, "minimal@example.com")
        XCTAssertTrue(user.groupIds.isEmpty)
    }
    
    func testUserEquality() {
        // Two users with different properties but same UID
        let timestamp1 = Timestamp(date: Date())
        let timestamp2 = Timestamp(date: Date().addingTimeInterval(3600)) // 1 hour later
        
        let user1 = halfhazard.User(
            uid: "same-uid",
            displayName: "User One",
            email: "one@example.com",
            groupIds: ["group1"],
            createdAt: timestamp1,
            lastActive: timestamp1
        )
        
        let user2 = halfhazard.User(
            uid: "same-uid",
            displayName: "User Two", // Different name
            email: "two@example.com", // Different email
            groupIds: ["group2"], // Different groups
            createdAt: timestamp1,
            lastActive: timestamp2 // Different last active time
        )
        
        // Test Hashable/Equatable conformance
        // Since User doesn't explicitly conform to Equatable, we'll test using the id property
        XCTAssertEqual(user1.id, user2.id)
        
        // Test with different UIDs
        let user3 = halfhazard.User(
            uid: "different-uid",
            displayName: "User One",
            email: "one@example.com",
            groupIds: ["group1"],
            createdAt: timestamp1,
            lastActive: timestamp1
        )
        
        XCTAssertNotEqual(user1.id, user3.id)
    }
    
    func testGroupModel() {
        // Create a group
        let group = Group(
            id: "test-group",
            name: "Test Group",
            memberIds: ["user1", "user2"],
            createdBy: "user1",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Description"),
            settled: false,
            settledAt: nil
        )
        
        // Test group properties
        XCTAssertEqual(group.id, "test-group")
        XCTAssertEqual(group.name, "Test Group")
        XCTAssertEqual(group.memberIds, ["user1", "user2"])
        XCTAssertEqual(group.createdBy, "user1")
        XCTAssertEqual(group.settings.name, "Test Description")
        XCTAssertFalse(group.settled)
        XCTAssertNil(group.settledAt)
        
        // Create a settled group
        let settledTimestamp = Timestamp()
        let settledGroup = Group(
            id: "settled-group",
            name: "Settled Group",
            memberIds: ["user1", "user2"],
            createdBy: "user1",
            createdAt: Timestamp(),
            settings: Settings(name: "Settled Group"),
            settled: true,
            settledAt: settledTimestamp
        )
        
        // Test settled group properties
        XCTAssertEqual(settledGroup.id, "settled-group")
        XCTAssertTrue(settledGroup.settled)
        XCTAssertEqual(settledGroup.settledAt, settledTimestamp)
        
        // Test equality
        let sameGroup = Group(
            id: "test-group",
            name: "Different Name", // Name is different but should still be equal
            memberIds: ["user1", "user3"], // Different members but should still be equal
            createdBy: "user1",
            createdAt: Timestamp(),
            settings: Settings(name: "Different Description"),
            settled: true, // Different settled status but should still be equal
            settledAt: Timestamp() // Different timestamp but should still be equal
        )
        XCTAssertEqual(group, sameGroup) // Groups with same ID should be equal
        
        // Test inequality
        let differentGroup = Group(
            id: "different-group",
            name: "Test Group", // Same name but different ID
            memberIds: ["user1", "user2"],
            createdBy: "user1",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Description"),
            settled: false,
            settledAt: nil
        )
        XCTAssertNotEqual(group, differentGroup) // Groups with different IDs should not be equal
    }
    
    func testExpenseModel() {
        // Create an expense
        let expense = Expense(
            id: "test-expense",
            amount: 100.0,
            description: "Test Expense",
            groupId: "test-group",
            createdBy: "user1",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: [
                "user1": 50.0,
                "user2": 50.0
            ],
            settled: false,
            settledAt: nil
        )
        
        // Test expense properties
        XCTAssertEqual(expense.id, "test-expense")
        XCTAssertEqual(expense.amount, 100.0)
        XCTAssertEqual(expense.description, "Test Expense")
        XCTAssertEqual(expense.groupId, "test-group")
        XCTAssertEqual(expense.createdBy, "user1")
        XCTAssertEqual(expense.splitType, .equal)
        XCTAssertEqual(expense.splits["user1"], 50.0)
        XCTAssertEqual(expense.splits["user2"], 50.0)
        XCTAssertFalse(expense.settled)
        XCTAssertNil(expense.settledAt)
        
        // Create a settled expense
        let settledTimestamp = Timestamp()
        let settledExpense = Expense(
            id: "settled-expense",
            amount: 100.0,
            description: "Settled Expense",
            groupId: "test-group",
            createdBy: "user1",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: [
                "user1": 50.0,
                "user2": 50.0
            ],
            settled: true,
            settledAt: settledTimestamp
        )
        
        // Test settled expense properties
        XCTAssertTrue(settledExpense.settled)
        XCTAssertEqual(settledExpense.settledAt, settledTimestamp)
        
        // Test equality
        let sameExpense = Expense(
            id: "test-expense",
            amount: 200.0, // Different amount but should still be equal
            description: "Different Description", // Different description but should still be equal
            groupId: "different-group", // Different group but should still be equal
            createdBy: "user2", // Different creator but should still be equal
            createdAt: Timestamp(),
            splitType: .currentUserOwed, // Different split type but should still be equal
            splits: ["user1": 100.0, "user2": 100.0], // Different splits but should still be equal
            settled: true, // Different settled status but should still be equal
            settledAt: Timestamp() // Different settled timestamp but should still be equal
        )
        XCTAssertEqual(expense, sameExpense) // Expenses with same ID should be equal
        
        // Test inequality
        let differentExpense = Expense(
            id: "different-expense",
            amount: 100.0,
            description: "Test Expense",
            groupId: "test-group",
            createdBy: "user1",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["user1": 50.0, "user2": 50.0],
            settled: false,
            settledAt: nil
        )
        XCTAssertNotEqual(expense, differentExpense) // Expenses with different IDs should not be equal
    }
    
    func testExpenseWithNilDescription() {
        // Create an expense with nil description
        let expense = Expense(
            id: "null-description-expense",
            amount: 75.0,
            description: nil,
            groupId: "test-group",
            createdBy: "user1",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["user1": 37.5, "user2": 37.5],
            settled: false,
            settledAt: nil
        )
        
        // Test that nil description is handled correctly
        XCTAssertNil(expense.description)
        XCTAssertEqual(expense.amount, 75.0)
    }
    
    func testExpenseZeroAmount() {
        // Create an expense with zero amount (edge case)
        let expense = Expense(
            id: "zero-expense",
            amount: 0.0,
            description: "Zero Amount Expense",
            groupId: "test-group",
            createdBy: "user1",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["user1": 0.0, "user2": 0.0],
            settled: false,
            settledAt: nil
        )
        
        // Test that zero amount is handled correctly
        XCTAssertEqual(expense.amount, 0.0)
        XCTAssertEqual(expense.splits["user1"], 0.0)
        XCTAssertEqual(expense.splits["user2"], 0.0)
    }
    
    func testExpenseWithCustomSplits() {
        // Create an expense with custom split type and uneven splits
        let expense = Expense(
            id: "custom-split-expense",
            amount: 100.0,
            description: "Custom Split Expense",
            groupId: "test-group",
            createdBy: "user1",
            createdAt: Timestamp(),
            splitType: .custom,
            splits: ["user1": 75.0, "user2": 25.0],
            settled: false,
            settledAt: nil
        )
        
        // Test that custom splits are handled correctly
        XCTAssertEqual(expense.splitType, .custom)
        XCTAssertEqual(expense.splits["user1"], 75.0)
        XCTAssertEqual(expense.splits["user2"], 25.0)
        
        // Verify that the total of splits equals the expense amount
        let totalSplits = expense.splits.values.reduce(0, +)
        XCTAssertEqual(totalSplits, expense.amount)
    }
    
    func testExpenseHashValue() {
        // Create two expenses with same ID but different properties
        let expense1 = Expense(
            id: "hash-test-expense",
            amount: 50.0,
            description: "Hash Test 1",
            groupId: "group1",
            createdBy: "user1",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["user1": 25.0, "user2": 25.0],
            settled: false,
            settledAt: nil
        )
        
        let expense2 = Expense(
            id: "hash-test-expense",
            amount: 100.0,
            description: "Hash Test 2",
            groupId: "group2",
            createdBy: "user2",
            createdAt: Timestamp(),
            splitType: .custom,
            splits: ["user1": 60.0, "user2": 40.0],
            settled: true,
            settledAt: Timestamp()
        )
        
        // Test that hash values are equal (since they're based on ID)
        var hasher1 = Hasher()
        var hasher2 = Hasher()
        expense1.hash(into: &hasher1)
        expense2.hash(into: &hasher2)
        
        // And verify that they're considered equal by Set
        let expenseSet = Set([expense1, expense2])
        XCTAssertEqual(expenseSet.count, 1) // Only one unique expense should be in the set
    }
    
    func testExpenseSettled() {
        // Test the settled property functionality
        let settledTimestamp = Timestamp()
        let settledExpense = Expense(
            id: "settled-test-expense",
            amount: 100.0,
            description: "Settled Expense Test",
            groupId: "test-group",
            createdBy: "user1",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["user1": 50.0, "user2": 50.0],
            settled: true,
            settledAt: settledTimestamp
        )
        
        XCTAssertTrue(settledExpense.settled)
        XCTAssertEqual(settledExpense.settledAt, settledTimestamp)
        
        // Create an unsettled expense
        let unsettledExpense = Expense(
            id: "unsettled-test-expense",
            amount: 100.0,
            description: "Unsettled Expense Test",
            groupId: "test-group",
            createdBy: "user1",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["user1": 50.0, "user2": 50.0],
            settled: false,
            settledAt: nil
        )
        
        XCTAssertFalse(unsettledExpense.settled)
        XCTAssertNil(unsettledExpense.settledAt)
    }
    
    func testGroupSettled() {
        // Test the settled property functionality for groups
        let settledTimestamp = Timestamp()
        let settledGroup = Group(
            id: "settled-test-group",
            name: "Settled Group Test",
            memberIds: ["user1", "user2"],
            createdBy: "user1",
            createdAt: Timestamp(),
            settings: Settings(name: "Settled Group Test"),
            settled: true,
            settledAt: settledTimestamp
        )
        
        XCTAssertTrue(settledGroup.settled)
        XCTAssertEqual(settledGroup.settledAt, settledTimestamp)
        
        // Create an unsettled group
        let unsettledGroup = Group(
            id: "unsettled-test-group",
            name: "Unsettled Group Test",
            memberIds: ["user1", "user2"],
            createdBy: "user1",
            createdAt: Timestamp(),
            settings: Settings(name: "Unsettled Group Test"),
            settled: false,
            settledAt: nil
        )
        
        XCTAssertFalse(unsettledGroup.settled)
        XCTAssertNil(unsettledGroup.settledAt)
    }
    
    func testSplitTypeModel() {
        // Test all enum cases
        XCTAssertEqual(SplitType.equal.rawValue, "equal")
        XCTAssertEqual(SplitType.currentUserOwes.rawValue, "currentUserOwes")
        XCTAssertEqual(SplitType.currentUserOwed.rawValue, "currentUserOwed")
        XCTAssertEqual(SplitType.custom.rawValue, "custom")
        
        // Test initialization from raw value
        XCTAssertEqual(SplitType(rawValue: "equal"), .equal)
        XCTAssertEqual(SplitType(rawValue: "currentUserOwes"), .currentUserOwes)
        XCTAssertEqual(SplitType(rawValue: "currentUserOwed"), .currentUserOwed)
        XCTAssertEqual(SplitType(rawValue: "custom"), .custom)
        XCTAssertNil(SplitType(rawValue: "invalid"))
    }
    
    func testSettingsModel() {
        // Test creating a settings object
        let settings = Settings(name: "Test Settings")
        XCTAssertEqual(settings.name, "Test Settings")
    }
    
    func testCustomSplitPercentages() {
        // Test creating an expense with custom split percentages
        let percentages = ["user1": 60.0, "user2": 40.0]
        let expense = Expense(
            id: "percentage-expense",
            amount: 100.0,
            description: "Percentage Test",
            groupId: "test-group",
            createdBy: "user1",
            createdAt: Timestamp(),
            splitType: .custom,
            splits: ["user1": 60.0, "user2": 40.0],
            customSplitPercentages: percentages
        )
        
        XCTAssertEqual(expense.customSplitPercentages?["user1"], 60.0)
        XCTAssertEqual(expense.customSplitPercentages?["user2"], 40.0)
    }
    
    func testPercentageValidation() {
        // Test valid percentages
        let validPercentages = ["user1": 60.0, "user2": 40.0]
        XCTAssertTrue(Expense.validatePercentages(validPercentages))
        
        // Test invalid percentages (sum > 100)
        let invalidPercentages1 = ["user1": 60.0, "user2": 50.0]
        XCTAssertFalse(Expense.validatePercentages(invalidPercentages1))
        
        // Test invalid percentages (sum < 100)
        let invalidPercentages2 = ["user1": 30.0, "user2": 40.0]
        XCTAssertFalse(Expense.validatePercentages(invalidPercentages2))
        
        // Test edge case: exactly 100%
        let exactPercentages = ["user1": 50.0, "user2": 50.0]
        XCTAssertTrue(Expense.validatePercentages(exactPercentages))
    }
    
    func testCalculateSplitsFromPercentages() {
        let percentages = ["user1": 75.0, "user2": 25.0]
        let amount = 100.0
        let splits = Expense.calculateSplitsFromPercentages(percentages, amount: amount)
        
        XCTAssertEqual(splits["user1"], 75.0)
        XCTAssertEqual(splits["user2"], 25.0)
        
        // Test with different amount
        let splits2 = Expense.calculateSplitsFromPercentages(percentages, amount: 200.0)
        XCTAssertEqual(splits2["user1"], 150.0)
        XCTAssertEqual(splits2["user2"], 50.0)
    }
    
    func testApplyCustomSplitPercentages() {
        let percentages = ["user1": 80.0, "user2": 20.0]
        var expense = Expense(
            id: "apply-percentage-expense",
            amount: 50.0,
            description: "Apply Percentage Test",
            groupId: "test-group",
            createdBy: "user1",
            createdAt: Timestamp(),
            splitType: .custom,
            splits: ["user1": 25.0, "user2": 25.0], // Initial equal splits
            customSplitPercentages: percentages
        )
        
        // Apply the custom percentages
        expense.applyCustomSplitPercentages()
        
        // Check that splits were updated
        XCTAssertEqual(expense.splits["user1"], 40.0) // 80% of 50
        XCTAssertEqual(expense.splits["user2"], 10.0) // 20% of 50
    }
}