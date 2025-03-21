//
//  GroupService.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class GroupService: ObservableObject {
    // setup firebase
    let db = Firestore.firestore()

    // Create a new group with the current user as creator
    func createGroup(groupName: String, groupDescription: String?) async throws -> Group {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "GroupService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Create a new document reference with auto-generated ID
        let groupRef = db.collection("groups").document()
        
        // Create a new group
        let group = Group(
            id: groupRef.documentID,
            name: groupName,
            memberIds: [currentUser.uid],
            createdBy: currentUser.uid,
            createdAt: Timestamp(),
            settings: Settings(name: groupDescription ?? "")
        )
        
        // Save group to Firestore
        try groupRef.setData(from: group)
        
        // Update the user's groupIds array
        let userRef = db.collection("users").document(currentUser.uid)
        try await userRef.updateData([
            "groupIds": FieldValue.arrayUnion([groupRef.documentID])
        ])
        
        return group
    }
    
    func updateGroupMembership(groupID: String, userID: String) async throws {
        // Get the group
        let groupRef = db.collection("groups").document(groupID)
        let group = try await groupRef.getDocument(as: Group.self)
        
        // Check if user is already a member
        if !group.memberIds.contains(userID) {
            // Add user to group
            try await groupRef.updateData([
                "memberIds": FieldValue.arrayUnion([userID])
            ])
            
            // Add group to user's groups
            let userRef = db.collection("users").document(userID)
            try await userRef.updateData([
                "groupIds": FieldValue.arrayUnion([groupID])
            ])
        }
    }
    
    func deleteGroup(groupID: String) async throws {
        // Get group to get member IDs before deletion
        let group = try await db.collection("groups").document(groupID).getDocument(as: Group.self)
        
        // Delete group
        try await db.collection("groups").document(groupID).delete()
        
        // Remove group from all member users' groupIds arrays
        for userID in group.memberIds {
            let userRef = db.collection("users").document(userID)
            try await userRef.updateData([
                "groupIds": FieldValue.arrayRemove([groupID])
            ])
        }
    }
    
    func getGroupInfo(groupID: String) async throws -> Group {
        return try await db.collection("groups").document(groupID).getDocument(as: Group.self)
    }
    
    func getGroupMembers(groupID: String) async throws -> [User] {
        // Get the group to access memberIds
        let group = try await getGroupInfo(groupID: groupID)
        
        // Create an array to hold the users
        var members: [User] = []
        
        // Fetch each user by their ID
        for userID in group.memberIds {
            do {
                let userDoc = try await db.collection("users").document(userID).getDocument(as: User.self)
                members.append(userDoc)
            } catch {
                print("Error fetching user with ID \(userID): \(error)")
                // Continue with next user if one fails
                continue
            }
        }
        
        return members
    }
}
