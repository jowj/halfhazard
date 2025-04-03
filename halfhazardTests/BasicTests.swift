//
//  BasicTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-23.
//

import XCTest
import FirebaseFirestore
@testable import halfhazard

// Basic tests to ensure the test framework is working
final class BasicTests: XCTestCase {
    
    func testThatTestsRun() {
        XCTAssertTrue(true, "This test should always pass")
    }
    
    func testUserModel() {
        // Create a user
        let user = User(
            uid: "test-uid",
            displayName: "Test User",
            email: "test@example.com",
            groupIds: ["group1", "group2"],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        // Test user properties
        XCTAssertEqual(user.uid, "test-uid")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.groupIds, ["group1", "group2"])
    }
    
    func testGroupModel() {
        // Create a group
        let group = Group(
            id: "test-group",
            name: "Test Group",
            memberIds: ["user1", "user2"],
            createdBy: "user1",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Description")
        )
        
        // Test group properties
        XCTAssertEqual(group.id, "test-group")
        XCTAssertEqual(group.name, "Test Group")
        XCTAssertEqual(group.memberIds, ["user1", "user2"])
        XCTAssertEqual(group.createdBy, "user1")
        XCTAssertEqual(group.settings.name, "Test Description")
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
            splitType: SplitType.equal,
            splits: [
                "user1": 50.0,
                "user2": 50.0
            ]
        )
        
        // Test expense properties
        XCTAssertEqual(expense.id, "test-expense")
        XCTAssertEqual(expense.amount, 100.0)
        XCTAssertEqual(expense.description, "Test Expense")
        XCTAssertEqual(expense.groupId, "test-group")
        XCTAssertEqual(expense.createdBy, "user1")
        XCTAssertEqual(expense.splitType, SplitType.equal)
        XCTAssertEqual(expense.splits["user1"], 50.0)
        XCTAssertEqual(expense.splits["user2"], 50.0)
    }
}