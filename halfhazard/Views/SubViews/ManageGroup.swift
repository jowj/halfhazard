//
//  ManageGroup.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-06-08.
// Manage an individual group's settings
// Users? Public vs private? Archive? 

import SwiftUI
import SwiftData

struct ManageGroup: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userID") var userID: String = ""
    
    @Binding var navigationPath: NavigationPath
    
    var group: userGroup
    
    @Query private var users: [User]
    
    @State private var selectedUserID: String?
    
    var body: some View {
        Form {
            Text("Currently modifying group: \(group.name)") // Assuming Group has a name property
            
            Section("Do you want to add a user?") {
                VStack {
                    Picker("Assign User", selection: $selectedUserID) {
                        Text("Select a user").tag(nil as String?)
                        ForEach(users) { user in
                            Text(user.name ?? "Unknown").tag(user.userID as String?)
                        }
                    }
                    .onChange(of: selectedUserID) { oldValue, newValue in
                        if let newValue = newValue {
                            addUserToGroup(userID: newValue)
                        }
                    }
                    
                    if let selectedUserID = selectedUserID,
                       let selectedUser = users.first(where: { $0.userID == selectedUserID }) {
                        Text("Selected: \(selectedUser.name ?? "Unknown")")
                    }
                }
            }
            
            Section("These users already exist:") {
                ForEach(group.unwrappedMembers) { member in
                    HStack {
                        Text(member.name ?? "Unknown")
                        Spacer()
                        Button("Remove") {
                            removeUserFromGroup(user: member)
                        }
                    }
                }
            }
            Button("Done") {
                navigationPath.removeLast()
            }
        }
    }
    
    private func addUserToGroup(userID: String) {
        guard let user = users.first(where: { $0.userID == userID }),
              !group.unwrappedMembers.contains(where: { $0.userID == userID }) else {
            return
        }
        
        group.members?.append(user)
        
        do {
            try context.save()
            selectedUserID = nil // Reset selection after adding
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    private func removeUserFromGroup(user: User) {
        group.members?.removeAll(where: { $0.userID == user.userID })
        
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}


private extension ManageGroup {

    func save(selectedGroup: userGroup, user: User) {
        group.members?.append(user)
    }
    
}
