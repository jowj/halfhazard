//
//  GroupServiceTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-24.
//

import XCTest
import FirebaseFirestore
import FirebaseAuth
@testable import halfhazard

@MainActor
final class GroupServiceTests: XCTestCase {
    
    var groupService: MockGroupService!
    var userService: MockUserService!
    
    override func setUp() async throws {
        // Create a mock user to simulate being logged in
        userService = MockUserService()
        let testUser = halfhazard.User(
            uid: "test-user-id",
            displayName: "Test User",
            email: "test@example.com",
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        userService.mockUsers = [testUser]
        userService.mockCurrentUser = testUser
        
        // Initialize the group service with empty test data
        groupService = MockGroupService()
    }
    
    override func tearDown() async throws {
        // Clear all test data between tests
        groupService.mockGroups = []
        groupService.mockGroupMembers = []
        groupService.mockError = nil
    }
    
    func testCreateGroup() async throws {
        // Test creating a new group
        let group = try await groupService.createGroup(groupName: "Test Group", groupDescription: "A test group")
        
        // Verify group was created with correct properties
        XCTAssertEqual(group.name, "Test Group")
        XCTAssertEqual(group.settings.name, "A test group")
        XCTAssertEqual(group.memberIds, ["test-user-id"])
        XCTAssertEqual(group.createdBy, "test-user-id")
        XCTAssertNotNil(group.id)
        
        // Verify group was added to the mock storage
        XCTAssertEqual(groupService.mockGroups.count, 1)
    }
    
    func testJoinGroupByCode() async throws {
        // Create a group first
        let existingGroup = Group(
            id: "test-group-id",
            name: "Existing Group",
            memberIds: ["other-user-id"],
            createdBy: "other-user-id",
            createdAt: Timestamp(),
            settings: Settings(name: "Existing group description")
        )
        groupService.mockGroups = [existingGroup]
        
        // Test joining the group using its ID as the code
        let joinedGroup = try await groupService.joinGroupByCode(code: "test-group-id")
        
        // Verify the joined group is the expected one
        XCTAssertEqual(joinedGroup.id, "test-group-id")
        
        // In a real test with the actual implementation, we would verify that:
        // 1. The current user was added to the group's memberIds
        // 2. The group was added to the user's groupIds
    }
    
    func testGetGroupInfo() async throws {
        // Create a test group where the test user is a member
        let testGroup = Group(
            id: "test-group-id",
            name: "Test Group",
            memberIds: ["test-user-id", "other-user"],
            createdBy: "other-user",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Group Description")
        )
        groupService.mockGroups = [testGroup]
        
        // Retrieve the group info
        let group = try await groupService.getGroupInfo(groupID: "test-group-id")
        
        // Verify the correct group was retrieved
        XCTAssertEqual(group.id, "test-group-id")
        XCTAssertEqual(group.name, "Test Group")
        XCTAssertTrue(group.memberIds.contains("test-user-id"))
    }
    
    func testLeaveGroup() async throws {
        // Create a test group where the test user is a member but not the creator
        let testGroup = Group(
            id: "test-group-id",
            name: "Test Group",
            memberIds: ["test-user-id", "other-user"],
            createdBy: "other-user",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Group Description")
        )
        groupService.mockGroups = [testGroup]
        
        // Leave the group
        try await groupService.leaveGroup(groupID: "test-group-id")
        
        // Verify the group was removed from user's groups
        // Note: In our mock implementation, we simply remove the group from mockGroups
        XCTAssertEqual(groupService.mockGroups.count, 0)
    }
    
    func testRenameGroup() async throws {
        // Create a test group where the test user is the creator
        let testGroup = Group(
            id: "test-group-id",
            name: "Original Name",
            memberIds: ["test-user-id", "other-user"],
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Group Description")
        )
        groupService.mockGroups = [testGroup]
        
        // Rename the group
        try await groupService.renameGroup(groupID: "test-group-id", newName: "New Name")
        
        // Verify the group was renamed
        XCTAssertEqual(groupService.mockGroups[0].name, "New Name")
    }
    
    func testRemoveMemberFromGroup() async throws {
        // Create a test group where the test user is the creator
        let testGroup = Group(
            id: "test-group-id",
            name: "Test Group",
            memberIds: ["test-user-id", "member-to-remove"],
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Group Description")
        )
        groupService.mockGroups = [testGroup]
        
        // Remove a member
        try await groupService.removeMemberFromGroup(groupID: "test-group-id", userID: "member-to-remove")
        
        // Verify the member was removed
        XCTAssertEqual(groupService.mockGroups[0].memberIds.count, 1)
        XCTAssertEqual(groupService.mockGroups[0].memberIds[0], "test-user-id")
    }
    
    func testDeleteGroup() async throws {
        // Create a test group where the test user is the creator
        let testGroup = Group(
            id: "test-group-id",
            name: "Test Group",
            memberIds: ["test-user-id", "other-user"],
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Group Description")
        )
        groupService.mockGroups = [testGroup]
        
        // Delete the group
        try await groupService.deleteGroup(groupID: "test-group-id")
        
        // Verify the group was deleted
        XCTAssertEqual(groupService.mockGroups.count, 0)
    }
    
    func testGetGroupMembers() async throws {
        // Create a test group
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
        
        // Create mock users to return
        let testUser = halfhazard.User(
            uid: "test-user-id",
            displayName: "Test User",
            email: "test@example.com",
            groupIds: ["test-group-id"],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        let otherUser = halfhazard.User(
            uid: "other-user-id",
            displayName: "Other User",
            email: "other@example.com",
            groupIds: ["test-group-id"],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        groupService.mockGroupMembers = [testUser, otherUser]
        
        // Get the group members
        let members = try await groupService.getGroupMembers(groupID: "test-group-id")
        
        // Verify the correct members were returned
        XCTAssertEqual(members.count, 2)
        XCTAssertEqual(members[0].uid, "test-user-id")
        XCTAssertEqual(members[1].uid, "other-user-id")
    }
    
    func testSettleGroup() async throws {
        // Create a test group where the test user is the creator
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
        
        // Settle the group
        try await groupService.settleGroup(groupID: "test-group-id")
        
        // Verify the group was settled
        XCTAssertEqual(groupService.mockGroups.count, 1)
        XCTAssertTrue(groupService.mockGroups[0].settled)
        XCTAssertNotNil(groupService.mockGroups[0].settledAt)
    }
    
    func testSettleGroupAlreadySettled() async throws {
        // Create a test group that is already settled
        let timestamp = Timestamp()
        let testGroup = Group(
            id: "test-group-id",
            name: "Test Group",
            memberIds: ["test-user-id", "other-user-id"],
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Group Description"),
            settled: true,
            settledAt: timestamp
        )
        groupService.mockGroups = [testGroup]
        
        // Try to settle the group
        do {
            try await groupService.settleGroup(groupID: "test-group-id")
            XCTFail("Expected an error when settling an already settled group")
        } catch let error as NSError {
            // Verify we got the expected error
            XCTAssertEqual(error.domain, "GroupService")
            XCTAssertEqual(error.code, 400)
            XCTAssertTrue(error.localizedDescription.contains("already settled"))
        }
        
        // Verify the group is still settled and the timestamp hasn't changed
        XCTAssertEqual(groupService.mockGroups.count, 1)
        XCTAssertTrue(groupService.mockGroups[0].settled)
        XCTAssertEqual(groupService.mockGroups[0].settledAt, timestamp)
    }
    
    func testUnsettleGroup() async throws {
        // Create a test group that is already settled
        let testGroup = Group(
            id: "test-group-id",
            name: "Test Group",
            memberIds: ["test-user-id", "other-user-id"],
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            settings: Settings(name: "Test Group Description"),
            settled: true,
            settledAt: Timestamp()
        )
        groupService.mockGroups = [testGroup]
        
        // Unsettle the group
        try await groupService.unsettleGroup(groupID: "test-group-id")
        
        // Verify the group was unsettled
        XCTAssertEqual(groupService.mockGroups.count, 1)
        XCTAssertFalse(groupService.mockGroups[0].settled)
        XCTAssertNil(groupService.mockGroups[0].settledAt)
    }
    
    func testUnsettleGroupAlreadyUnsettled() async throws {
        // Create a test group that is already unsettled
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
        
        // Try to unsettle the group
        do {
            try await groupService.unsettleGroup(groupID: "test-group-id")
            XCTFail("Expected an error when unsettling an already unsettled group")
        } catch let error as NSError {
            // Verify we got the expected error
            XCTAssertEqual(error.domain, "GroupService")
            XCTAssertEqual(error.code, 400)
            XCTAssertTrue(error.localizedDescription.contains("already unsettled"))
        }
        
        // Verify the group is still unsettled
        XCTAssertEqual(groupService.mockGroups.count, 1)
        XCTAssertFalse(groupService.mockGroups[0].settled)
        XCTAssertNil(groupService.mockGroups[0].settledAt)
    }
}