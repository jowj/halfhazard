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
            settings: Settings(name: groupDescription ?? ""),
            settled: false,
            settledAt: nil
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
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "GroupService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the group
        let groupRef = db.collection("groups").document(groupID)
        let group = try await groupRef.getDocument(as: Group.self)
        
        // Security check: Only the group creator or admins should be able to add users
        // or users should be able to add themselves (join)
        if currentUser.uid != group.createdBy && currentUser.uid != userID {
            throw NSError(domain: "GroupService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the group creator can add members, or users can add themselves"])
        }
        
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
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "GroupService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get group to get member IDs before deletion (using getGroupInfo which checks membership)
        let group = try await getGroupInfo(groupID: groupID)
        
        // Check if the current user is the creator of the group
        guard group.createdBy == currentUser.uid else {
            throw NSError(domain: "GroupService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the group creator can delete the group"])
        }
        
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
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "GroupService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the group
        let group = try await db.collection("groups").document(groupID).getDocument(as: Group.self)
        
        // Check if the current user is a member of this group
        guard group.memberIds.contains(currentUser.uid) else {
            throw NSError(domain: "GroupService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You are not a member of this group"])
        }
        
        return group
    }
    
    func joinGroupByCode(code: String) async throws -> Group {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "GroupService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // In a real implementation, this would likely query a separate collection of invite codes
        // For now, we'll assume the code is the group ID for simplicity
        let groupID = code
        
        // Get the group
        let groupRef = db.collection("groups").document(groupID)
        do {
            let group = try await groupRef.getDocument(as: Group.self)
            
            // Check if user is already a member
            if group.memberIds.contains(currentUser.uid) {
                return group // Already a member, just return the group
            }
            
            // Add user to the group
            try await updateGroupMembership(groupID: groupID, userID: currentUser.uid)
            
            // Get and return the updated group
            return try await groupRef.getDocument(as: Group.self)
        } catch {
            throw NSError(domain: "GroupService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid group code or group not found"])
        }
    }
    
    func leaveGroup(groupID: String) async throws {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "GroupService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the group info
        let groupRef = db.collection("groups").document(groupID)
        let group = try await groupRef.getDocument(as: Group.self)
        
        // Check if current user is a member
        guard group.memberIds.contains(currentUser.uid) else {
            throw NSError(domain: "GroupService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You are not a member of this group"])
        }
        
        // Check if user is the creator - creators can't leave without transferring ownership or deleting
        if group.createdBy == currentUser.uid && group.memberIds.count > 1 {
            throw NSError(domain: "GroupService", code: 400, userInfo: [NSLocalizedDescriptionKey: "As the group creator, you must transfer ownership or delete the group"])
        }
        
        // Remove user from group memberIds
        try await groupRef.updateData([
            "memberIds": FieldValue.arrayRemove([currentUser.uid])
        ])
        
        // Remove group from user's groupIds
        let userRef = db.collection("users").document(currentUser.uid)
        try await userRef.updateData([
            "groupIds": FieldValue.arrayRemove([groupID])
        ])
        
        // If this was the last member, delete the group
        if group.memberIds.count <= 1 {
            try await deleteGroup(groupID: groupID)
        }
    }
    
    func getGroupMembers(groupID: String) async throws -> [User] {
        // Get the group to access memberIds (this already checks if the user is a member)
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
    
    // Rename a group (group admin only)
    func renameGroup(groupID: String, newName: String) async throws {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "GroupService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Validate the new name
        guard !newName.isEmpty else {
            throw NSError(domain: "GroupService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Group name cannot be empty"])
        }
        
        // Get the group
        let groupRef = db.collection("groups").document(groupID)
        let group = try await groupRef.getDocument(as: Group.self)
        
        // Check if the current user is the group creator
        guard group.createdBy == currentUser.uid else {
            throw NSError(domain: "GroupService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the group creator can rename the group"])
        }
        
        // Update the group name
        try await groupRef.updateData([
            "name": newName
        ])
    }
    
    // Remove a user from a group (group admin only)
    func removeMemberFromGroup(groupID: String, userID: String) async throws {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "GroupService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the group
        let groupRef = db.collection("groups").document(groupID)
        let group = try await groupRef.getDocument(as: Group.self)
        
        // Check if the current user is the group creator
        guard group.createdBy == currentUser.uid else {
            throw NSError(domain: "GroupService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the group creator can remove members"])
        }
        
        // Cannot remove the group creator
        if userID == group.createdBy {
            throw NSError(domain: "GroupService", code: 400, userInfo: [NSLocalizedDescriptionKey: "The group creator cannot be removed"])
        }
        
        // Check if user is a member
        guard group.memberIds.contains(userID) else {
            throw NSError(domain: "GroupService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User is not a member of this group"])
        }
        
        // Remove user from group memberIds
        try await groupRef.updateData([
            "memberIds": FieldValue.arrayRemove([userID])
        ])
        
        // Remove group from user's groupIds
        let userRef = db.collection("users").document(userID)
        try await userRef.updateData([
            "groupIds": FieldValue.arrayRemove([groupID])
        ])
    }
    
    // Settle a group (mark all expenses as settled and the group as settled)
    func settleGroup(groupID: String) async throws {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "GroupService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the group
        let groupRef = db.collection("groups").document(groupID)
        let group = try await groupRef.getDocument(as: Group.self)
        
        // Check if the group is already settled
        if group.settled {
            throw NSError(domain: "GroupService", code: 400, userInfo: [NSLocalizedDescriptionKey: "This group is already settled"])
        }
        
        // Check if the current user is a member of the group (already verified in getGroupInfo)
        // We allow any member to settle the group now
        
        // Create a timestamp for the settlement
        let settlementTime = Timestamp()
        
        // Update the group as settled
        try await groupRef.updateData([
            "settled": true,
            "settledAt": settlementTime
        ])
        
        // Get all expenses in this group that are not settled
        let expensesSnapshot = try await db.collection("expenses")
            .whereField("groupId", isEqualTo: groupID)
            .whereField("settled", isEqualTo: false)
            .getDocuments()
        
        // Create a batch to update all expenses at once
        let batch = db.batch()
        for document in expensesSnapshot.documents {
            batch.updateData([
                "settled": true,
                "settledAt": settlementTime
            ], forDocument: document.reference)
        }
        
        // Commit the batch
        try await batch.commit()
    }
    
    // Unsettle a group (mark the group as not settled)
    func unsettleGroup(groupID: String) async throws {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "GroupService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the group
        let groupRef = db.collection("groups").document(groupID)
        let group = try await groupRef.getDocument(as: Group.self)
        
        // Check if the group is already unsettled
        if !group.settled {
            throw NSError(domain: "GroupService", code: 400, userInfo: [NSLocalizedDescriptionKey: "This group is already unsettled"])
        }
        
        // Check if the current user is a member of the group (already verified in getGroupInfo)
        // We allow any member to unsettle the group now
        
        // Update the group as unsettled
        try await groupRef.updateData([
            "settled": false,
            "settledAt": FieldValue.delete()
        ])
    }
}
