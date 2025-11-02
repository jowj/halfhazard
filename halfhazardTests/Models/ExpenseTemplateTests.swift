//
//  ExpenseTemplateTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-11-02.
//

import XCTest
import FirebaseFirestore
@testable import halfhazard

final class ExpenseTemplateTests: XCTestCase {

    func testTemplateItemCreateExpense_EqualSplit() {
        // Given
        let item = TemplateItem(
            amount: 100.0,
            description: "Test expense",
            splitType: .equal
        )
        let groupMembers = ["user1", "user2"]

        // When
        let expense = item.createExpense(
            forGroup: "group1",
            createdBy: "user1",
            groupMembers: groupMembers
        )

        // Then
        XCTAssertEqual(expense.amount, 100.0)
        XCTAssertEqual(expense.splitType, .equal)
        XCTAssertEqual(expense.splits["user1"], 50.0)
        XCTAssertEqual(expense.splits["user2"], 50.0)
    }

    func testTemplateItemCreateExpense_CurrentUserOwes() {
        // Given
        let item = TemplateItem(
            amount: 100.0,
            description: "Test expense",
            splitType: .currentUserOwes
        )
        let groupMembers = ["user1", "user2"]

        // When
        let expense = item.createExpense(
            forGroup: "group1",
            createdBy: "user1",
            groupMembers: groupMembers
        )

        // Then
        XCTAssertEqual(expense.amount, 100.0)
        XCTAssertEqual(expense.splitType, .currentUserOwes)
        XCTAssertEqual(expense.splits["user1"], 100.0)
        XCTAssertNil(expense.splits["user2"])
    }

    func testTemplateItemCreateExpense_CurrentUserOwed() {
        // Given - This is the bug we fixed!
        let item = TemplateItem(
            amount: 100.0,
            description: "Test expense",
            splitType: .currentUserOwed
        )
        let groupMembers = ["user1", "user2", "user3"]

        // When
        let expense = item.createExpense(
            forGroup: "group1",
            createdBy: "user1",
            groupMembers: groupMembers
        )

        // Then
        XCTAssertEqual(expense.amount, 100.0)
        XCTAssertEqual(expense.splitType, .currentUserOwed)

        // Current user (who paid) should have 0 split
        XCTAssertEqual(expense.splits["user1"], 0.0)

        // Other members should split equally
        XCTAssertEqual(expense.splits["user2"], 50.0)
        XCTAssertEqual(expense.splits["user3"], 50.0)
    }

    func testTemplateItemCreateExpense_CurrentUserOwed_OnlyMember() {
        // Given - Edge case where user is only member
        let item = TemplateItem(
            amount: 100.0,
            description: "Test expense",
            splitType: .currentUserOwed
        )
        let groupMembers = ["user1"]

        // When
        let expense = item.createExpense(
            forGroup: "group1",
            createdBy: "user1",
            groupMembers: groupMembers
        )

        // Then
        XCTAssertEqual(expense.amount, 100.0)
        XCTAssertEqual(expense.splitType, .currentUserOwed)
        XCTAssertEqual(expense.splits["user1"], 0.0)
    }

    func testTemplateItemCreateExpense_CustomSplit() {
        // Given
        let customPercentages = ["user1": 30.0, "user2": 70.0]
        let item = TemplateItem(
            amount: 100.0,
            description: "Test expense",
            splitType: .custom,
            customSplitPercentages: customPercentages
        )
        let groupMembers = ["user1", "user2"]

        // When
        let expense = item.createExpense(
            forGroup: "group1",
            createdBy: "user1",
            groupMembers: groupMembers
        )

        // Then
        XCTAssertEqual(expense.amount, 100.0)
        XCTAssertEqual(expense.splitType, .custom)

        // Check that custom percentages were applied
        XCTAssertEqual(expense.splits["user1"] ?? 0, 30.0, accuracy: 0.01)
        XCTAssertEqual(expense.splits["user2"] ?? 0, 70.0, accuracy: 0.01)
        XCTAssertEqual(expense.customSplitPercentages, customPercentages)
    }

    func testTemplateItemValidateCustomSplits_Valid() {
        // Given
        let item = TemplateItem(
            amount: 100.0,
            description: "Test expense",
            splitType: .custom,
            customSplitPercentages: ["user1": 40.0, "user2": 60.0]
        )

        // When
        let isValid = item.validateCustomSplits()

        // Then
        XCTAssertTrue(isValid)
    }

    func testTemplateItemValidateCustomSplits_Invalid() {
        // Given
        let item = TemplateItem(
            amount: 100.0,
            description: "Test expense",
            splitType: .custom,
            customSplitPercentages: ["user1": 40.0, "user2": 50.0] // Only sums to 90%
        )

        // When
        let isValid = item.validateCustomSplits()

        // Then
        XCTAssertFalse(isValid)
    }

    func testExpenseTemplateTotalAmount() {
        // Given
        let items = [
            TemplateItem(amount: 25.0, description: "Item 1", splitType: .equal),
            TemplateItem(amount: 50.0, description: "Item 2", splitType: .equal),
            TemplateItem(amount: 25.0, description: "Item 3", splitType: .equal)
        ]
        let template = ExpenseTemplate(
            name: "Test Template",
            createdBy: "user1",
            templateItems: items
        )

        // When
        let total = template.totalAmount

        // Then
        XCTAssertEqual(total, 100.0)
    }

    func testExpenseTemplateGetPreview() {
        // Given
        let items = [
            TemplateItem(amount: 10.0, description: "Item 1", splitType: .equal),
            TemplateItem(amount: 20.0, description: "Item 2", splitType: .equal),
            TemplateItem(amount: 30.0, description: "Item 3", splitType: .equal),
            TemplateItem(amount: 40.0, description: "Item 4", splitType: .equal),
            TemplateItem(amount: 50.0, description: "Item 5", splitType: .equal)
        ]
        let template = ExpenseTemplate(
            name: "Test Template",
            createdBy: "user1",
            templateItems: items
        )

        // When
        let preview = template.getPreview(limit: 3)

        // Then
        XCTAssertEqual(preview.count, 3)
        XCTAssertEqual(preview[0].amount, 10.0)
        XCTAssertEqual(preview[1].amount, 20.0)
        XCTAssertEqual(preview[2].amount, 30.0)
    }
}
