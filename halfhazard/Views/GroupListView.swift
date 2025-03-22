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
            List(groupViewModel.groups, selection: $groupViewModel.selectedGroup) { group in
                Text(group.name)
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Groups")
            
            Divider()
            
            // Group action buttons in footer
            VStack(spacing: 8) {
                // Create Group button
                Button(action: {
                    groupViewModel.showingCreateGroupSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create Group")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.horizontal)
                
                // Join Group button
                Button(action: {
                    groupViewModel.showingJoinGroupSheet = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Join Group")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.horizontal)
                
                // Group actions - only visible when a group is selected
                if let selectedGroup = groupViewModel.selectedGroup {
                    Divider()
                        .padding(.vertical, 4)
                        .padding(.horizontal)
                    
                    // Share Group button - to let others join
                    Button(action: {
                        // This would typically copy the group ID to clipboard
                        // For now just show it in a sheet
                        groupViewModel.showingShareGroupSheet = true
                    }) {
                        HStack {
                            Image(systemName: "person.2.badge.gearshape")
                            Text("Manage \"\(selectedGroup.name)\"")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.regular)
                    .padding(.horizontal)
                    
                    // Leave Group button
                    Button(action: {
                        if selectedGroup.createdBy == groupViewModel.currentUser?.uid {
                            // For creators, show delete confirmation instead
                            groupViewModel.showingDeleteConfirmation = true
                        } else {
                            // For regular members, show leave confirmation
                            groupViewModel.showingLeaveConfirmation = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Leave \"\(selectedGroup.name)\"")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .controlSize(.regular)
                    .padding(.horizontal)
                }
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
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Manage Group")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(group.name)
                    .font(.title3)
                    .foregroundColor(.secondary)
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
                    // In a real implementation, we would fetch and display the actual group members
                    Text("You are \(group.createdBy == viewModel.currentUser?.uid ? "the owner" : "a member") of this group")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .frame(minWidth: 450, minHeight: 400)
        .alert("Delete Group", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteCurrentGroup()
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this group? All expenses and data associated with the group will be permanently deleted. This action cannot be undone.")
        }
    }
}

#Preview {
    GroupListView(
        groupViewModel: GroupViewModel(currentUser: nil, useDevMode: true),
        expenseViewModel: ExpenseViewModel(currentUser: nil, useDevMode: true)
    )
}