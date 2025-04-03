//
//  ManageGroupSheet.swift
//  halfhazard
//
//  Created by Claude on 2025-04-01.
//

import SwiftUI
import FirebaseFirestore
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ManageGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let group: Group
    @ObservedObject var viewModel: GroupViewModel
    @State private var isInviteCodeCopied = false
    @State private var showDeleteConfirmation = false
    @State private var showRemoveMemberConfirmation = false
    @State private var memberToRemove: String? = nil
    @State private var isEditing = false
    @State private var newGroupName = ""
    @State private var showRenameSheet = false
    
    // State for storing member information
    @State private var members: [User] = []
    @State private var loadingMembers = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Manage Group")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Group name with rename button for owners
                HStack {
                    Text(group.name)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    if group.createdBy == viewModel.currentUser?.uid {
                        Button {
                            newGroupName = group.name
                            showRenameSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.top)
            
            // Group info and actions
            Form {
                // Group Invitation section
                Section(header: Text("Group Invitation")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Share this code with others to let them join your group:")
                            .font(.subheadline)
                        
                        HStack {
                            Text(group.id)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            
                            Button(action: {
                                #if os(macOS)
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(group.id, forType: .string)
                                #elseif os(iOS)
                                UIPasteboard.general.string = group.id
                                #endif
                                
                                // Show copied animation
                                withAnimation {
                                    isInviteCodeCopied = true
                                }
                                
                                // Reset after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    isInviteCodeCopied = false
                                }
                            }) {
                                Label(isInviteCodeCopied ? "Copied!" : "Copy Code", systemImage: isInviteCodeCopied ? "checkmark" : "clipboard")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Group Members section
                Section(header: Text("Members (\(group.memberIds.count))")) {
                    if loadingMembers {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else if members.isEmpty {
                        Text("No members found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        // Membership status text
                        Text("You are \(group.createdBy == viewModel.currentUser?.uid ? "the owner" : "a member") of this group")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                        
                        // Scrollable members list
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(members, id: \.uid) { member in
                                    HStack {
                                        // Member icon (initials)
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.2))
                                                .frame(width: 32, height: 32)
                                            
                                            Text(getInitials(for: member.displayName ?? member.email))
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        // Member info
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(member.displayName ?? member.email)
                                                .font(.body)
                                            
                                            if member.uid == group.createdBy {
                                                Text("Owner")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            } else if member.uid == viewModel.currentUser?.uid {
                                                Text("You")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Remove button - only shown for group owner and not self
                                        if group.createdBy == viewModel.currentUser?.uid && 
                                           member.uid != viewModel.currentUser?.uid {
                                            Button {
                                                memberToRemove = member.uid
                                                showRemoveMemberConfirmation = true
                                            } label: {
                                                Image(systemName: "person.fill.xmark")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                // Settlement status display - for all users
                Section(header: Text("Settlement Status")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            // Status label
                            if group.settled {
                                Label("Settled", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .fontWeight(.medium)
                            } else {
                                Label("Active", systemImage: "circle")
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // Settlement timestamp if available
                        if let settledAt = group.settledAt {
                            Text("Settled on: \(settledAt.dateValue().formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("You can manage the group's settlement status directly from the expense list.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 3)
                    }
                    .padding(.vertical, 8)
                }
                
                // Danger Zone section
                if group.createdBy == viewModel.currentUser?.uid {
                    Section(header: Text("Danger Zone").foregroundColor(.red)) {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Label("Delete Group", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            
            // Close button
            Button("Close") {
                // If we're in a navigation stack, go back
                if !viewModel.navigationPath.isEmpty {
                    viewModel.navigationPath.removeLast()
                } else {
                    // Fall back to Environment dismiss for sheet presentation
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .frame(minWidth: 450, minHeight: 400)
        .task {
            // Load member information when the view appears
            loadingMembers = true
            do {
                members = try await viewModel.groupService.getGroupMembers(groupID: group.id)
                loadingMembers = false
            } catch {
                errorMessage = "Failed to load group members: \(error.localizedDescription)"
                loadingMembers = false
            }
        }
        .alert("Delete Group", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteCurrentGroup()
                    // Navigation back is handled in the deleteCurrentGroup method for path
                    // But we still need to dismiss the sheet if presented as sheet
                    if viewModel.navigationPath.isEmpty {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this group? All expenses and data associated with the group will be permanently deleted. This action cannot be undone.")
        }
        .alert("Remove Member", isPresented: $showRemoveMemberConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let memberId = memberToRemove {
                    Task {
                        await removeMember(memberId)
                    }
                }
            }
        } message: {
            if let memberId = memberToRemove, let member = members.first(where: { $0.uid == memberId }) {
                Text("Are you sure you want to remove \(member.displayName ?? member.email) from this group?")
            } else {
                Text("Are you sure you want to remove this member from the group?")
            }
        }
        
        // Error alert
        .alert("Error", isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        // Rename sheet
        .sheet(isPresented: $showRenameSheet) {
            VStack(spacing: 20) {
                Text("Rename Group")
                    .font(.title2)
                    .fontWeight(.bold)
                
                TextField("Group Name", text: $newGroupName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                HStack {
                    Button("Cancel") {
                        showRenameSheet = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save") {
                        Task {
                            await renameGroup()
                            showRenameSheet = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newGroupName.isEmpty || newGroupName == group.name)
                }
                .padding()
            }
            .padding()
            .frame(width: 350, height: 200)
        }
    }
    
    // Helper to get initials from a name
    private func getInitials(for name: String) -> String {
        let components = name.components(separatedBy: " ")
        if components.count > 1, 
           let first = components.first?.first,
           let last = components.last?.first {
            return "\(first)\(last)"
        } else if let first = name.first {
            return String(first)
        } else if let atIndex = name.firstIndex(of: "@"), name.startIndex != atIndex {
            // For email addresses, use first character
            return String(name[name.startIndex])
        }
        return "?"
    }
    
    // Function to remove a member from the group
    @MainActor
    private func removeMember(_ memberId: String) async {
        do {
            // Create a GroupService instance to handle removing the member
            try await viewModel.groupService.removeMemberFromGroup(groupID: group.id, userID: memberId)
            
            // Update the local list by removing the member
            members.removeAll(where: { $0.uid == memberId })
            
            // Clear the selected member
            memberToRemove = nil
        } catch {
            errorMessage = "Failed to remove member: \(error.localizedDescription)"
        }
    }
    
    // Function to rename the group
    @MainActor
    private func renameGroup() async {
        do {
            // Call the service to update the group name
            try await viewModel.groupService.renameGroup(groupID: group.id, newName: newGroupName)
            
            // Update the viewModel to reflect the changes
            if let index = viewModel.groups.firstIndex(where: { $0.id == group.id }) {
                // Create a mutable copy of the group
                var updatedGroup = viewModel.groups[index]
                // Update the name
                updatedGroup.name = newGroupName
                // Replace the group in the array
                viewModel.groups[index] = updatedGroup
                
                // If this is the selected group, update it too
                if viewModel.selectedGroup?.id == group.id {
                    viewModel._selectedGroup = updatedGroup
                }
            }
        } catch {
            errorMessage = "Failed to rename group: \(error.localizedDescription)"
        }
    }
}

// Preview Provider
#Preview {
    // Mock data for preview
    let timestamp = Timestamp()
    let mockGroup = Group(
        id: "mock-group-id",
        name: "Mock Group",
        memberIds: ["user1", "user2", "user3"],
        createdBy: "user1",
        createdAt: timestamp,
        settings: Settings(name: ""),
        settled: false,
        settledAt: nil
    )
    
    return ManageGroupSheet(
        group: mockGroup,
        viewModel: GroupViewModel(currentUser: nil, useDevMode: true)
    )
}