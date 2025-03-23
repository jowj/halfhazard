//
//  MockFirebaseTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-25.
//

import XCTest
import FirebaseFirestore
@testable import halfhazard

/**
 * Tests for the protocol-based Firebase mock implementation.
 */
final class MockFirebaseTests: XCTestCase {
    
    // Mock providers
    var mockAuth: MockUserProvider!
    var mockFirestore: MockFirestoreProvider!
    var userCollection: MockCollectionProvider!
    var groupCollection: MockCollectionProvider!
    
    override func setUp() async throws {
        mockAuth = MockUserProvider(uid: "firebase-uid", email: "firebase@example.com", displayName: "Firebase User")
        mockFirestore = MockFirestoreProvider()
        
        // Set up collections
        userCollection = mockFirestore.collection("users") as? MockCollectionProvider
        groupCollection = mockFirestore.collection("groups") as? MockCollectionProvider
        
        // Add test documents
        let userData: [String: Any] = [
            "uid": "firebase-uid",
            "email": "firebase@example.com",
            "displayName": "Firebase User",
            "groupIds": ["group1", "group2"],
            "createdAt": Timestamp(),
            "lastActive": Timestamp()
        ]
        
        try await userCollection.document("firebase-uid").setData(userData, merge: false)
        
        let groupData: [String: Any] = [
            "id": "group1",
            "name": "Firebase Group",
            "memberIds": ["firebase-uid", "other-uid"],
            "createdBy": "firebase-uid",
            "createdAt": Timestamp(),
            "settings": ["name": "Firebase Group Description"]
        ]
        
        try await groupCollection.document("group1").setData(groupData, merge: false)
    }
    
    override func tearDown() async throws {
        mockAuth = nil
        mockFirestore = nil
        userCollection = nil
        groupCollection = nil
    }
    
    // MARK: - Firestore Tests
    
    func testFirestoreDocument_SetAndGet() async throws {
        // Test setting and getting document data
        let docRef = mockFirestore.collection("test").document("doc1")
        
        // Set data
        try await docRef.setData(["name": "Test Doc", "value": 123], merge: false)
        
        // Get document
        let snapshot = try await docRef.getDocument()
        XCTAssertTrue(snapshot.exists)
        XCTAssertEqual(snapshot.documentID, "doc1")
        
        // Verify data
        let data = snapshot.data()
        XCTAssertEqual(data?["name"] as? String, "Test Doc")
        XCTAssertEqual(data?["value"] as? Int, 123)
    }
    
    func testFirestoreQuery_WhereField() async throws {
        // Add multiple documents to test querying
        let testCollection = mockFirestore.collection("test-query")
        
        try await testCollection.document("doc1").setData(["category": "A", "value": 10], merge: false)
        try await testCollection.document("doc2").setData(["category": "A", "value": 20], merge: false)
        try await testCollection.document("doc3").setData(["category": "B", "value": 30], merge: false)
        
        // Query documents where category = "A"
        let query = testCollection.whereField("category", isEqualTo: "A")
        let snapshot = try await query.getDocuments()
        
        // Verify query results
        XCTAssertEqual(snapshot.documents.count, 2)
        
        // Check that all documents have category = "A"
        for document in snapshot.documents {
            XCTAssertEqual(document.data()?["category"] as? String, "A")
        }
    }
    
    func testFirestoreDocument_UpdateData() async throws {
        // Create a document to update
        let docRef = mockFirestore.collection("test-update").document("update1")
        try await docRef.setData(["field1": "original", "field2": 100], merge: false)
        
        // Update a single field
        try await docRef.updateData(["field1": "updated"])
        
        // Verify the update
        let snapshot = try await docRef.getDocument()
        let data = snapshot.data()
        
        XCTAssertEqual(data?["field1"] as? String, "updated")
        XCTAssertEqual(data?["field2"] as? Int, 100) // Should remain unchanged
    }
    
    // MARK: - Auth Provider Tests
    
    func testMockUserProvider() {
        // Test user provider properties
        XCTAssertEqual(mockAuth.uid, "firebase-uid")
        XCTAssertEqual(mockAuth.email, "firebase@example.com")
        XCTAssertEqual(mockAuth.displayName, "Firebase User")
    }
}