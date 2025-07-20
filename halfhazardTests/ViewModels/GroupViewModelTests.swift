//
//  GroupViewModelTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-24.
//

import XCTest
import FirebaseFirestore
import FirebaseAuth
@testable import halfhazard

@MainActor
final class GroupViewModelTests: XCTestCase {
    
    var viewModel: GroupViewModel!
    var mockGroupService: MockGroupService!
    var testUser: halfhazard.User!
    
    override func setUp() async throws {
        // Create a test user
        testUser = halfhazard.User(
            uid: "test-user-id",
            displayName: "Test User",
            email: "test@example.com",
            groupIds: ["group1", "group2"],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        // Create the mock service
        mockGroupService = MockGroupService()
        
        // Setup the view model with our test user and dev mode enabled
        viewModel = GroupViewModel(currentUser: testUser, useDevMode: true)
        
        // For now, we'll skip replacing the GroupService, since we're in dev mode anyway
        // and it would require complex, potentially unsafe memory manipulation
        
        // Prepare some test groups
        let group1 = Group(
            id: "group1",
            name: "Group One",
            memberIds: ["test-user-id"],
            createdBy: "test-user-id",
            createdAt: Timestamp(),
            settings: Settings(name: "Group One Description")
        )
        
        let group2 = Group(
            id: "group2",
            name: "Group Two",
            memberIds: ["test-user-id", "other-user"],
            createdBy: "other-user",
            createdAt: Timestamp(),
            settings: Settings(name: "Group Two Description")
        )
        
        mockGroupService.mockGroups = [group1, group2]
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockGroupService = nil
        testUser = nil
    }
    
    func testLoadGroups() async throws {
        // Load the groups
        await viewModel.loadGroups()
        
        // When in dev mode, no groups are actually loaded from Firebase
        // So we're just testing that loading completes without error
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testCreateGroup() async throws {
        // Set form values
        viewModel.newGroupName = "New Test Group"
        viewModel.newGroupDescription = "New Test Group Description"
        
        // Initial count
        XCTAssertEqual(viewModel.groups.count, 0)
        
        // Create the group
        await viewModel.createGroup()
        
        // Check that the group was created and added
        XCTAssertEqual(viewModel.groups.count, 1)
        XCTAssertEqual(viewModel.groups[0].name, "New Test Group")
        XCTAssertEqual(viewModel.groups[0].settings.name, "New Test Group Description")
        
        // Check that the form was reset
        XCTAssertEqual(viewModel.newGroupName, "")
        XCTAssertEqual(viewModel.newGroupDescription, "")
    }
    
    func testJoinGroup() async throws {
        // Set form values
        viewModel.joinGroupCode = "join-group-id"
        
        // Initial count
        XCTAssertEqual(viewModel.groups.count, 0)
        
        // Join the group
        await viewModel.joinGroup()
        
        // Check that the group was added
        XCTAssertEqual(viewModel.groups.count, 1)
        XCTAssertEqual(viewModel.groups[0].id, "join-group-id")
        
        // Check that the group was selected
        XCTAssertNotNil(viewModel.selectedGroup)
        XCTAssertEqual(viewModel.selectedGroup?.id, "join-group-id")
        
        // Check that the form was reset
        XCTAssertEqual(viewModel.joinGroupCode, "")
    }
    
    func testLeaveGroup() async throws {
        // First load the groups so we have some data
        await viewModel.loadGroups()
        
        // Add mock groups to the view model directly, since we're in dev mode
        viewModel.groups = [
            Group(
                id: "group1",
                name: "Group One",
                memberIds: ["test-user-id"],
                createdBy: "test-user-id",
                createdAt: Timestamp(),
                settings: Settings(name: "Group One Description")
            ),
            Group(
                id: "group2",
                name: "Group Two",
                memberIds: ["test-user-id", "other-user"],
                createdBy: "other-user",
                createdAt: Timestamp(),
                settings: Settings(name: "Group Two Description")
            )
        ]
        viewModel.selectedGroup = viewModel.groups[0]
        
        // Initial count and selection
        XCTAssertEqual(viewModel.groups.count, 2)
        XCTAssertNotNil(viewModel.selectedGroup)
        XCTAssertEqual(viewModel.selectedGroup?.id, "group1")
        
        // Leave the selected group
        await viewModel.leaveCurrentGroup()
        
        // Check that the group was removed
        XCTAssertEqual(viewModel.groups.count, 1)
        XCTAssertFalse(viewModel.groups.contains(where: { $0.id == "group1" }))
        
        // Check that the selection was updated to the next available group
        XCTAssertNotNil(viewModel.selectedGroup)
        XCTAssertEqual(viewModel.selectedGroup?.id, "group2")
    }
    
    func testDeleteGroup() async throws {
        // First load the groups so we have some data
        await viewModel.loadGroups()
        
        // Add mock groups to the view model directly, since we're in dev mode
        viewModel.groups = [
            Group(
                id: "group1",
                name: "Group One",
                memberIds: ["test-user-id"],
                createdBy: "test-user-id",
                createdAt: Timestamp(),
                settings: Settings(name: "Group One Description")
            ),
            Group(
                id: "group2",
                name: "Group Two",
                memberIds: ["test-user-id", "other-user"],
                createdBy: "other-user",
                createdAt: Timestamp(),
                settings: Settings(name: "Group Two Description")
            )
        ]
        viewModel.selectedGroup = viewModel.groups[0]
        
        // Initial count and selection
        XCTAssertEqual(viewModel.groups.count, 2)
        XCTAssertNotNil(viewModel.selectedGroup)
        XCTAssertEqual(viewModel.selectedGroup?.id, "group1")
        
        // Delete the selected group
        await viewModel.deleteCurrentGroup()
        
        // Check that the group was removed
        XCTAssertEqual(viewModel.groups.count, 1)
        XCTAssertFalse(viewModel.groups.contains(where: { $0.id == "group1" }))
        
        // Check that the selection was updated to the next available group
        XCTAssertNotNil(viewModel.selectedGroup)
        XCTAssertEqual(viewModel.selectedGroup?.id, "group2")
    }
    
    func testDeleteLastGroup() async throws {
        // First load the groups so we have some data
        await viewModel.loadGroups()
        
        // Add a single mock group to the view model directly
        viewModel.groups = [
            Group(
                id: "single-group",
                name: "Single Group", 
                memberIds: ["test-user-id"],
                createdBy: "test-user-id",
                createdAt: Timestamp(),
                settings: Settings(name: "Single Group Description")
            )
        ]
        viewModel.selectedGroup = viewModel.groups[0]
        
        // Initial count and selection
        XCTAssertEqual(viewModel.groups.count, 1)
        XCTAssertNotNil(viewModel.selectedGroup)
        XCTAssertEqual(viewModel.selectedGroup?.id, "single-group")
        
        // Delete the selected group
        await viewModel.deleteCurrentGroup()
        
        // Check that the group was removed and selection cleared
        XCTAssertEqual(viewModel.groups.count, 0)
        XCTAssertNil(viewModel.selectedGroup)
    }
}