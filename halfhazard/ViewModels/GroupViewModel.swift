//
//  GroupViewModel.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import Foundation
import FirebaseFirestore
import Combine
import SwiftUI

class GroupViewModel: ObservableObject {
    // Services
    // Make groupService public so it can be used by views
    let groupService = GroupService()
    
    // State
    @Published var groups: [Group] = []
    @Published var _selectedGroup: Group?
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    // Custom setter/getter for selectedGroup to add debugging
    var selectedGroup: Group? {
        get {
            return _selectedGroup
        }
        set {
            print("GroupViewModel: Setting selected group to \(newValue?.name ?? "nil")")
            _selectedGroup = newValue
        }
    }
    
    // Form state
    @Published var newGroupName = ""
    @Published var newGroupDescription = ""
    @Published var joinGroupCode = ""
    
    // Navigation state
    enum Destination: Hashable {
        case createGroup
        case joinGroup
        case manageGroup(Group)
    }
    
    @Published var navigationPath = NavigationPath()
    @Published var showingLeaveConfirmation = false
    @Published var showingDeleteConfirmation = false
    
    // Current user
    var currentUser: User?
    
    // Development mode
    var useDevMode = false
    
    init(currentUser: User?, useDevMode: Bool = false) {
        self.currentUser = currentUser
        self.useDevMode = useDevMode
    }
    
    @MainActor
    func loadGroups() async {
        guard let currentUser = currentUser else { return }
        
        // Skip for dev mode since we don't have real Firebase data
        if useDevMode {
            isLoading = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        var loadedGroups: [Group] = []
        
        for groupId in currentUser.groupIds {
            do {
                let group = try await groupService.getGroupInfo(groupID: groupId)
                loadedGroups.append(group)
            } catch let error as NSError {
                if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                    // If we hit a permissions error, show the user a helpful message
                    errorMessage = """
                    Firestore permissions error.
                    
                    You need to set up Firestore security rules. Please:
                    1. Go to Firebase Console -> Firestore Database
                    2. Go to the Rules tab
                    3. Replace rules with the content from the firestore.rules.dev file for development
                    4. Publish the rules
                    
                    For development, you can use permissive rules. Make sure to use proper rules in production.
                    """
                    print("Firestore permissions error loading group \(groupId): \(error)")
                    return
                } else if error.domain == "GroupService" && error.code == 403 {
                    // Access control error - user not a member of the group
                    print("Access denied to group \(groupId): \(error.localizedDescription)")
                    // Skip this group - don't add to loadedGroups
                    continue
                } else if error.domain == "GroupService" && error.code == 401 {
                    // Authentication error
                    errorMessage = "Authentication required: \(error.localizedDescription)"
                    print("Authentication error loading group \(groupId): \(error)")
                    return
                } else {
                    print("Error loading group \(groupId): \(error)")
                }
            }
        }
        
        groups = loadedGroups.sorted(by: { $0.name < $1.name })
        
        if groups.count > 0 && _selectedGroup == nil {
            print("GroupViewModel.loadGroups: Setting initial group to \(groups.first?.name ?? "nil")")
            _selectedGroup = groups.first
        }
    }
    
    @MainActor
    func createGroup() async {
        guard !newGroupName.isEmpty else {
            errorMessage = "Group name cannot be empty"
            return
        }
        
        // Handle dev mode - create mock group
        if useDevMode {
            let groupId = "dev-group-\(UUID().uuidString)"
            let timestamp = Timestamp()
            let mockGroup = Group(
                id: groupId,
                name: newGroupName,
                memberIds: [currentUser?.uid ?? "dev-user"],
                createdBy: currentUser?.uid ?? "dev-user",
                createdAt: timestamp,
                settings: Settings(name: newGroupDescription.isEmpty ? "" : newGroupDescription),
                settled: false,
                settledAt: nil
            )
            
            // Add to our array
            groups.append(mockGroup)
            
            // Sort the groups
            groups.sort { $0.name < $1.name }
            
            // Select the new group
            selectedGroup = mockGroup
            
            // Reset form fields
            resetFormFields()
            
            // Navigate back
            if !navigationPath.isEmpty {
                navigationPath.removeLast()
            }
            return
        }
        
        do {
            let group = try await groupService.createGroup(
                groupName: newGroupName, 
                groupDescription: newGroupDescription.isEmpty ? nil : newGroupDescription
            )
            
            // Add the new group to our array
            groups.append(group)
            
            // Sort the groups by name
            groups.sort { $0.name < $1.name }
            
            // Select the new group
            selectedGroup = group
            
            // Reset form fields
            resetFormFields()
            
            // Navigate back
            if !navigationPath.isEmpty {
                navigationPath.removeLast()
            }
        } catch let error as NSError {
            if error.domain == "FIRFirestoreErrorDomain" && error.code == 7 {
                errorMessage = """
                Firestore permissions error.
                
                You need to set up Firestore security rules. Please:
                1. Go to Firebase Console -> Firestore Database
                2. Go to the Rules tab
                3. Replace rules with the content from the firestore.rules.dev file for development
                4. Publish the rules
                
                For development, you can use permissive rules. Make sure to use proper rules in production.
                """
            } else if error.domain == "GroupService" && error.code == 403 {
                // Access control error
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                // Authentication error
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to create group: \(error.localizedDescription)"
            }
            print("Error creating group: \(error)")
        }
    }
    
    @MainActor
    func joinGroup() async {
        guard !joinGroupCode.isEmpty else {
            errorMessage = "Group code cannot be empty"
            return
        }
        
        // Handle dev mode
        if useDevMode {
            // Mock joining a group
            let groupId = joinGroupCode
            let timestamp = Timestamp()
            let mockGroup = Group(
                id: groupId,
                name: "Joined Group \(joinGroupCode)",
                memberIds: [currentUser?.uid ?? "dev-user"],
                createdBy: "dev-creator",
                createdAt: timestamp,
                settings: Settings(name: "Joined via code"),
                settled: false,
                settledAt: nil
            )
            
            // Add to our array if not already present
            if !groups.contains(where: { $0.id == groupId }) {
                groups.append(mockGroup)
                
                // Sort the groups
                groups.sort { $0.name < $1.name }
                
                // Select the new group
                selectedGroup = mockGroup
            } else {
                // Group already exists, just select it
                selectedGroup = groups.first(where: { $0.id == groupId })
            }
            
            // Reset form fields
            joinGroupCode = ""
            
            // Navigate back
            if !navigationPath.isEmpty {
                navigationPath.removeLast()
            }
            return
        }
        
        do {
            let group = try await groupService.joinGroupByCode(code: joinGroupCode)
            
            // Add the group to our array if not already present
            if !groups.contains(where: { $0.id == group.id }) {
                groups.append(group)
                
                // Sort the groups
                groups.sort { $0.name < $1.name }
                
                // Select the new group
                selectedGroup = group
            } else {
                // Group already exists, just select it
                selectedGroup = groups.first(where: { $0.id == group.id })
            }
            
            // Reset form field
            joinGroupCode = ""
            
            // Navigate back
            if !navigationPath.isEmpty {
                navigationPath.removeLast()
            }
        } catch let error as NSError {
            if error.domain == "GroupService" && error.code == 404 {
                errorMessage = "Invalid group code or group not found."
            } else if error.domain == "GroupService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to join group: \(error.localizedDescription)"
            }
            print("Error joining group: \(error)")
        }
    }
    
    @MainActor
    func leaveCurrentGroup() async {
        guard let group = selectedGroup else { return }
        
        // Handle dev mode
        if useDevMode {
            // Remove from our array
            groups.removeAll(where: { $0.id == group.id })
            
            // Update selection
            if groups.isEmpty {
                selectedGroup = nil
            } else {
                selectedGroup = groups.first
            }
            return
        }
        
        do {
            try await groupService.leaveGroup(groupID: group.id)
            
            // Remove from our array
            groups.removeAll(where: { $0.id == group.id })
            
            // Update selection
            if groups.isEmpty {
                selectedGroup = nil
            } else {
                selectedGroup = groups.first
            }
        } catch let error as NSError {
            if error.domain == "GroupService" && error.code == 400 {
                // Special case for group creators - we should offer to delete the group instead
                errorMessage = "As the group creator, you can't leave the group. You can delete the group instead."
            } else if error.domain == "GroupService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to leave group: \(error.localizedDescription)"
            }
            print("Error leaving group: \(error)")
        }
    }
    
    @MainActor
    func deleteCurrentGroup() async {
        guard let group = selectedGroup else { return }
        
        // Handle dev mode
        if useDevMode {
            // Remove from our array
            groups.removeAll(where: { $0.id == group.id })
            
            // Update selection
            if groups.isEmpty {
                selectedGroup = nil
            } else {
                selectedGroup = groups.first
            }
            return
        }
        
        do {
            try await groupService.deleteGroup(groupID: group.id)
            
            // Remove from our array
            groups.removeAll(where: { $0.id == group.id })
            
            // Update selection
            if groups.isEmpty {
                selectedGroup = nil
            } else {
                selectedGroup = groups.first
            }
        } catch let error as NSError {
            if error.domain == "GroupService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to delete group: \(error.localizedDescription)"
            }
            print("Error deleting group: \(error)")
        }
    }
    
    private func resetFormFields() {
        newGroupName = ""
        newGroupDescription = ""
        joinGroupCode = ""
    }
    
    // Navigation helper methods
    func showCreateGroupForm() {
        navigationPath.append(Destination.createGroup)
    }
    
    func showJoinGroupForm() {
        navigationPath.append(Destination.joinGroup)
    }
    
    func showManageGroupForm(for group: Group) {
        navigationPath.append(Destination.manageGroup(group))
    }
    
    @MainActor
    func settleCurrentGroup() async {
        guard let group = selectedGroup else { return }
        
        // Handle dev mode
        if useDevMode {
            // Update in our array
            if let index = groups.firstIndex(where: { $0.id == group.id }) {
                var updatedGroup = group
                updatedGroup.settled = true
                updatedGroup.settledAt = Timestamp()
                groups[index] = updatedGroup
                selectedGroup = updatedGroup
            }
            return
        }
        
        do {
            try await groupService.settleGroup(groupID: group.id)
            
            // Update in our array
            if let index = groups.firstIndex(where: { $0.id == group.id }) {
                var updatedGroup = group
                updatedGroup.settled = true
                updatedGroup.settledAt = Timestamp()
                groups[index] = updatedGroup
                selectedGroup = updatedGroup
            }
        } catch let error as NSError {
            if error.domain == "GroupService" && error.code == 400 {
                errorMessage = "This group is already settled"
            } else if error.domain == "GroupService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to settle group: \(error.localizedDescription)"
            }
            print("Error settling group: \(error)")
        }
    }
    
    @MainActor
    func unsettleCurrentGroup() async {
        guard let group = selectedGroup else { return }
        
        // Check if the group is already unsettled
        guard group.settled else {
            errorMessage = "This group is already unsettled"
            return
        }
        
        // Handle dev mode
        if useDevMode {
            // Update in our array
            if let index = groups.firstIndex(where: { $0.id == group.id }) {
                var updatedGroup = group
                updatedGroup.settled = false
                updatedGroup.settledAt = nil
                groups[index] = updatedGroup
                selectedGroup = updatedGroup
            }
            return
        }
        
        do {
            try await groupService.unsettleGroup(groupID: group.id)
            
            // Update in our array
            if let index = groups.firstIndex(where: { $0.id == group.id }) {
                var updatedGroup = group
                updatedGroup.settled = false
                updatedGroup.settledAt = nil
                groups[index] = updatedGroup
                selectedGroup = updatedGroup
            }
        } catch let error as NSError {
            if error.domain == "GroupService" && error.code == 400 {
                errorMessage = "This group is already unsettled"
            } else if error.domain == "GroupService" && error.code == 403 {
                errorMessage = "Access denied: \(error.localizedDescription)"
            } else if error.domain == "GroupService" && error.code == 401 {
                errorMessage = "Authentication required: \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to unsettle group: \(error.localizedDescription)"
            }
            print("Error unsettling group: \(error)")
        }
    }
    
    // We no longer need a separate update method as we access the properties directly
}