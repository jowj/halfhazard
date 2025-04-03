//
//  UserServiceTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-24.
//

import XCTest
import FirebaseFirestore
import FirebaseAuth
@testable import halfhazard

@MainActor
final class UserServiceTests: XCTestCase {
    
    var userService: MockUserService!
    
    override func setUp() async throws {
        // Initialize the user service with empty test data
        userService = MockUserService()
    }
    
    override func tearDown() async throws {
        // Clear all test data between tests
        userService.mockUsers = []
        userService.mockCurrentUser = nil
        userService.mockError = nil
    }
    
    func testCreateUser() async throws {
        // Test creating a new user
        let user = try await userService.createUser(
            email: "test@example.com",
            password: "password123",
            displayName: "Test User"
        ) as halfhazard.User
        
        // Verify user was created with correct properties
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.groupIds, [])
        XCTAssertNotNil(user.uid)
        
        // Verify user was added to the mock storage and set as current user
        XCTAssertEqual(userService.mockUsers.count, 1)
        XCTAssertEqual(userService.mockCurrentUser?.uid, user.uid)
    }
    
    func testSignIn() async throws {
        // Create a user first
        let existingUser = halfhazard.User(
            uid: "test-uid",
            displayName: "Existing User",
            email: "existing@example.com",
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        userService.mockUsers = [existingUser]
        
        // Test signing in with the existing user
        let user = try await userService.signIn(
            email: "existing@example.com",
            password: "password123"
        ) as halfhazard.User
        
        // Verify the correct user was returned and set as current user
        XCTAssertEqual(user.uid, "test-uid")
        XCTAssertEqual(user.email, "existing@example.com")
        XCTAssertEqual(userService.mockCurrentUser?.uid, "test-uid")
    }
    
    func testSignOut() async throws {
        // Create and set a current user first
        let currentUser = halfhazard.User(
            uid: "current-uid",
            displayName: "Current User",
            email: "current@example.com",
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        userService.mockUsers = [currentUser]
        userService.mockCurrentUser = currentUser
        
        // Test signing out
        try userService.signOut()
        
        // Verify the current user was cleared
        XCTAssertNil(userService.mockCurrentUser)
    }
    
    func testGetUser() async throws {
        // Create some test users
        let user1 = halfhazard.User(
            uid: "user1-uid",
            displayName: "User One",
            email: "user1@example.com",
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        let user2 = halfhazard.User(
            uid: "user2-uid",
            displayName: "User Two",
            email: "user2@example.com",
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        userService.mockUsers = [user1, user2]
        
        // Test getting a specific user
        let retrievedUser = try await userService.getUser(uid: "user2-uid")
        
        // Verify the correct user was retrieved
        XCTAssertEqual(retrievedUser.uid, "user2-uid")
        XCTAssertEqual(retrievedUser.displayName, "User Two")
    }
    
    func testGetUserNotFound() async throws {
        // Test getting a non-existent user
        do {
            _ = try await userService.getUser(uid: "nonexistent-uid")
            XCTFail("Expected an error to be thrown")
        } catch let error as NSError {
            // Verify the correct error was thrown
            XCTAssertEqual(error.domain, "UserService")
            XCTAssertEqual(error.code, 404)
        }
    }
    
    func testUpdateUser() async throws {
        // Create a test user
        let user = halfhazard.User(
            uid: "test-uid",
            displayName: "Original Name",
            email: "test@example.com",
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        userService.mockUsers = [user]
        
        // Create an updated version of the user
        var updatedUser = user
        updatedUser.displayName = "Updated Name"
        updatedUser.groupIds = ["group1", "group2"]
        
        // Test updating the user
        try await userService.updateUser(updatedUser)
        
        // Verify the user was updated in the mock storage
        XCTAssertEqual(userService.mockUsers[0].displayName, "Updated Name")
        XCTAssertEqual(userService.mockUsers[0].groupIds, ["group1", "group2"])
    }
    
    func testDeleteUser() async throws {
        // Create a test user
        let user = halfhazard.User(
            uid: "test-uid",
            displayName: "Test User",
            email: "test@example.com",
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        userService.mockUsers = [user]
        userService.mockCurrentUser = user
        
        // Test deleting the user
        try await userService.deleteUser(uid: "test-uid")
        
        // Verify the user was removed from the mock storage and current user was cleared
        XCTAssertEqual(userService.mockUsers.count, 0)
        XCTAssertNil(userService.mockCurrentUser)
    }
    
    func testGetCurrentUser() async throws {
        // Create and set a current user
        let currentUser = halfhazard.User(
            uid: "current-uid",
            displayName: "Current User",
            email: "current@example.com",
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        userService.mockUsers = [currentUser]
        userService.mockCurrentUser = currentUser
        
        // Test getting the current user
        let user = try await userService.getCurrentUser()
        
        // Verify the correct user was returned
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.uid, "current-uid")
    }
    
    func testGetCurrentUserWhenNotSignedIn() async throws {
        // Test getting the current user when no user is signed in
        let user = try await userService.getCurrentUser()
        
        // Verify null was returned
        XCTAssertNil(user)
    }
}