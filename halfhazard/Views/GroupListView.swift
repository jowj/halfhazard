//
//  GroupListView.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct GroupListView: View {
    @ObservedObject var groupViewModel: GroupViewModel
    @ObservedObject var expenseViewModel: ExpenseViewModel
    var isInSplitView: Bool = false
    
    var body: some View {
        if isInSplitView {
            // In split view, don't wrap in NavigationStack (it's in the detail pane)
            groupListContent
        } else {
            // On iOS, use NavigationStack here
            NavigationStack(path: $groupViewModel.navigationPath) {
                groupListContent
            }
        }
    }
    
    private var groupListContent: some View {
        VStack(spacing: 0) {
            List {
                ForEach(groupViewModel.groups) { group in
                    HStack {
                        // Group name
                        Text(group.name)
                            .foregroundColor(groupViewModel.selectedGroup?.id == group.id ? .accentColor : .primary)
                            .font(groupViewModel.selectedGroup?.id == group.id ? .headline : .body)
                        
                        // Settlement indicator
                        if group.settled {
                            Text("Settled")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // Selected indicator
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
                            groupViewModel.showManageGroupForm(for: group)
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
                        // When in split view, this will show on the detail view
                        if isInSplitView {
                            // Clear any group selection to show the form in the detail area
                            groupViewModel.selectedGroup = nil
                        }
                        groupViewModel.showCreateGroupForm()
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
                    // When in split view, this will show on the detail view
                    if isInSplitView {
                        // Clear any group selection to show the form in the detail area
                        groupViewModel.selectedGroup = nil
                    }
                    groupViewModel.showJoinGroupForm()
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
            #if os(macOS)
            .background(Color(NSColor.windowBackgroundColor))
            #else
            .background(Color(.systemBackground))
            #endif
            
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
        // NavigationDestination is now defined in the detail column
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

#Preview {
    GroupListView(
        groupViewModel: GroupViewModel(currentUser: nil, useDevMode: true),
        expenseViewModel: ExpenseViewModel(currentUser: nil, useDevMode: true)
    )
}