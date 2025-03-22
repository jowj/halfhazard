//
//  GroupViewModel.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import Foundation
import FirebaseFirestore
import Combine

class GroupViewModel: ObservableObject {
    // Services
    private let groupService = GroupService()
    
    // State
    @Published var groups: [Group] = []
    @Published var selectedGroup: Group?
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    // Form state
    @Published var newGroupName = ""
    @Published var newGroupDescription = ""
    @Published var showingCreateGroupSheet = false
    
    // Current user
    private var currentUser: User?
    
    // Development mode
    private var useDevMode = false
    
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
                } else {
                    print("Error loading group \(groupId): \(error)")
                }
            }
        }
        
        groups = loadedGroups.sorted(by: { $0.name < $1.name })
        
        if groups.count > 0 && selectedGroup == nil {
            selectedGroup = groups.first
        }
    }
    
    @MainActor
    func createGroup() async {
        guard !newGroupName.isEmpty else { return }
        
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
                settings: Settings(name: newGroupDescription.isEmpty ? "" : newGroupDescription)
            )
            
            // Add to our array
            groups.append(mockGroup)
            
            // Sort the groups
            groups.sort { $0.name < $1.name }
            
            // Select the new group
            selectedGroup = mockGroup
            
            // Reset form fields
            resetFormFields()
            
            // Close the sheet
            showingCreateGroupSheet = false
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
            
            // Close the sheet
            showingCreateGroupSheet = false
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
            } else {
                errorMessage = "Failed to create group: \(error.localizedDescription)"
            }
            print("Error creating group: \(error)")
        }
    }
    
    private func resetFormFields() {
        newGroupName = ""
        newGroupDescription = ""
    }
    
    // Update user
    func updateUser(user: User?, devMode: Bool) {
        self.currentUser = user
        self.useDevMode = devMode
    }
}