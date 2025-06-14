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
    
    // AppNavigation
    var appNavigationRef: AppNavigation
    
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    // Helper function to format currency
    private func formatCurrency(_ amount: Double) -> String {
        return currencyFormatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    var body: some View {
        // macOS still uses the split view approach
        if isInSplitView {
            // In split view, don't wrap in NavigationStack (it's in the detail pane)
            groupListContent
        } else {
            // Always use the content directly on iOS - navigation is handled by the parent NavigationStack
            groupListContent
        }
    }
    
    private var groupListContent: some View {
        VStack(spacing: 0) {
            List {
                ForEach(groupViewModel.groups) { group in
                    HStack {
                        // Group name
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.name)
                                .foregroundColor(groupViewModel.selectedGroup?.id == group.id ? .accentColor : .primary)
                                .font(groupViewModel.selectedGroup?.id == group.id ? .headline : .body)
                            
                            // Status line showing both settlement status and balance
                            HStack(spacing: 6) {
                                // Settlement status indicator
                                if let allSettled = groupViewModel.groupsWithAllExpensesSettled[group.id], allSettled {
                                    Text("All Settled")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                
                                // Balance indicator - only show if there's a non-zero balance
                                if let balance = groupViewModel.groupBalances[group.id], abs(balance) > 0.01 {
                                    if balance > 0 {
                                        Text("You are owed \(formatCurrency(balance))")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("You owe \(formatCurrency(abs(balance)))")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
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
                        
                        // In iOS navigation stack mode, we want to navigate to the expenses for this group
                        if !isInSplitView {
                            appNavigationRef.navigateToGroupExpenses(group)
                        }
                    }
                    .background(groupViewModel.selectedGroup?.id == group.id ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(4)
                    .contextMenu {
                        Button(action: {
                            groupViewModel.selectedGroup = group
                            if !isInSplitView {
                                // Use unified navigation on iOS
                                appNavigationRef.showManageGroupForm(for: group)
                            } else {
                                // Use view model navigation for macOS
                                groupViewModel.navigateToManageGroup(for: group)
                            }
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
                            groupViewModel.navigateToCreateGroup()
                        } else {
                            // Use unified navigation on iOS
                            appNavigationRef.showCreateGroupForm()
                        }
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
                        groupViewModel.navigateToJoinGroup()
                    } else {
                        // Use unified navigation on iOS
                        appNavigationRef.showJoinGroupForm()
                    }
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
            await groupViewModel.updateAllGroupBalances()
        }
        .onAppear {
            // Make sure the GroupViewModel has a reference to AppNavigation
            groupViewModel.appNavigationRef = appNavigationRef
        }
    }
}

#Preview {
    // Create a mock AppNavigation for previews
    let mockAppNav = AppNavigation()
    
    return GroupListView(
        groupViewModel: GroupViewModel(currentUser: nil, useDevMode: true),
        expenseViewModel: ExpenseViewModel(currentUser: nil, useDevMode: true),
        appNavigationRef: mockAppNav
    )
}