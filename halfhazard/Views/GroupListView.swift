//
//  GroupListView.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import AppKit

struct GroupListView: View {
    @ObservedObject var groupViewModel: GroupViewModel
    @ObservedObject var expenseViewModel: ExpenseViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(groupViewModel.groups) { group in
                    HStack {
                        Text(group.name)
                            .foregroundColor(groupViewModel.selectedGroup?.id == group.id ? .accentColor : .primary)
                            .font(groupViewModel.selectedGroup?.id == group.id ? .headline : .body)
                        Spacer()
                        if groupViewModel.selectedGroup?.id == group.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                    .onTapGesture {
                        print("Group selected: \(group.name)")
                        groupViewModel.selectedGroup = group
                    }
                    .background(groupViewModel.selectedGroup?.id == group.id ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(4)
                    .contextMenu {
                        Button(action: {
                            groupViewModel.selectedGroup = group
                            groupViewModel.showingShareGroupSheet = true
                        }) {
                            Label("Manage Group", systemImage: "person.2.badge.gearshape")
                        }
                        
                        if group.createdBy == groupViewModel.currentUser?.uid {
                            // Only show delete option for group creators
                            Divider()
                            
                            Button(role: .destructive, action: {
                                groupViewModel.selectedGroup = group
                                groupViewModel.showingDeleteConfirmation = true
                            }) {
                                Label("Delete Group", systemImage: "trash")
                            }
                        } else {
                            // Show leave option for regular members
                            Divider()
                            
                            Button(role: .destructive, action: {
                                groupViewModel.selectedGroup = group
                                groupViewModel.showingLeaveConfirmation = true
                            }) {
                                Label("Leave Group", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        groupViewModel.showingCreateGroupSheet = true
                    }) {
                        Label("Add Group", systemImage: "plus")
                    }
                }
            }
            
            Divider()
            
            // Footer with Join Group button
            VStack(spacing: 8) {
                // Join Group button
                Button(action: {
                    groupViewModel.showingJoinGroupSheet = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Join Existing Group")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.horizontal)
                
                // Right-click hint - always visible
                Text("Right-click a group for more options")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            
            // Overlay for empty state or loading
            .overlay {
                if groupViewModel.groups.isEmpty && !groupViewModel.isLoading {
                    ContentUnavailableView("No Groups", 
                                          systemImage: "person.3",
                                          description: Text("Create or join a group to get started"))
                }
                
                if groupViewModel.isLoading {
                    ProgressView()
                }
            }
        }
        .sheet(isPresented: $groupViewModel.showingCreateGroupSheet) {
            CreateGroupForm(viewModel: groupViewModel)
        }
        .sheet(isPresented: $groupViewModel.showingJoinGroupSheet) {
            JoinGroupForm(viewModel: groupViewModel)
        }
        .sheet(isPresented: $groupViewModel.showingShareGroupSheet) {
            if let selectedGroup = groupViewModel.selectedGroup {
                ManageGroupSheet(group: selectedGroup, viewModel: groupViewModel)
            }
        }
        .alert("Leave Group", isPresented: $groupViewModel.showingLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task {
                    await groupViewModel.leaveCurrentGroup()
                }
            }
        } message: {
            if let group = groupViewModel.selectedGroup {
                Text("Are you sure you want to leave \"\(group.name)\"? You'll need an invite code to rejoin later.")
            }
        }
        .alert("Delete Group", isPresented: $groupViewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Group", role: .destructive) {
                Task {
                    await groupViewModel.deleteCurrentGroup()
                }
            }
        } message: {
            if let group = groupViewModel.selectedGroup {
                Text("As the group creator, you cannot leave \"\(group.name)\". You can delete the group instead, which will remove it for all members. This action cannot be undone.")
            }
        }
        .task {
            await groupViewModel.loadGroups()
        }
    }
}

struct JoinGroupForm: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: GroupViewModel
    @State private var isSubmitting = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Join Group")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Enter the group code provided by the group creator")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            // Form
            Form {
                TextField("Group Code", text: $viewModel.joinGroupCode)
                    .font(.title3)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal)
            
            // Action Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Join Group") {
                    Task {
                        isSubmitting = true
                        await viewModel.joinGroup()
                        isSubmitting = false
                        
                        // Only dismiss if there's no error message
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.joinGroupCode.isEmpty || isSubmitting)
                .keyboardShortcut(.defaultAction)
                .overlay {
                    if isSubmitting {
                        ProgressView()
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 280)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // Clear any previous error messages when the form appears
            viewModel.errorMessage = nil
        }
    }
}

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
            
            // Close button - only set the view model state
            Button("Close") {
                print("ManageGroupSheet: Close button pressed")
                // Only need to set the viewModel state, not call dismiss()
                viewModel.showingShareGroupSheet = false
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .frame(minWidth: 450, minHeight: 400)
        .onDisappear {
            print("ManageGroupSheet: onDisappear triggered")
            viewModel.showingShareGroupSheet = false
        }
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
                    // Only need to set the viewModel state, not call dismiss()
                    viewModel.showingShareGroupSheet = false
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

#Preview {
    GroupListView(
        groupViewModel: GroupViewModel(currentUser: nil, useDevMode: true),
        expenseViewModel: ExpenseViewModel(currentUser: nil, useDevMode: true)
    )
}