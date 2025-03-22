//
//  GroupListView.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct GroupListView: View {
    @ObservedObject var groupViewModel: GroupViewModel
    @ObservedObject var expenseViewModel: ExpenseViewModel
    
    var body: some View {
        VStack {
            List(groupViewModel.groups, selection: $groupViewModel.selectedGroup) { group in
                NavigationLink(value: group) {
                    Text(group.name)
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Groups")
            
            // Group-specific toolbar button without using toolbar modifier
            HStack {
                Button(action: {
                    groupViewModel.showingCreateGroupSheet = true
                }) {
                    Label("Add Group", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                Spacer()
            }
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