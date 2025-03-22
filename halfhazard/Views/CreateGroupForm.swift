//
//  CreateGroupForm.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import SwiftUI
import FirebaseFirestore

struct CreateGroupForm: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: GroupViewModel
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    
    var body: some View {
        Form {
            Section(header: Text("Group Details")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name").font(.caption).foregroundColor(.secondary)
                    TextField("Enter a name for your group", text: $groupName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.bottom, 10)
                        .onChange(of: groupName) { oldValue, newValue in
                            viewModel.newGroupName = newValue
                        }
                    
                    Text("Description (Optional)").font(.caption).foregroundColor(.secondary)
                    TextField("Enter a description", text: $groupDescription)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: groupDescription) { oldValue, newValue in
                            viewModel.newGroupDescription = newValue
                        }
                }
                .padding(.vertical, 10)
            }
            
            Section {
                Button("Create Group") {
                    Task {
                        await viewModel.createGroup()
                        dismiss()
                    }
                }
                .disabled(groupName.isEmpty)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Create New Group")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            // Initialize form fields from viewModel
            groupName = viewModel.newGroupName
            groupDescription = viewModel.newGroupDescription
        }
    }
}

#Preview {
    CreateGroupForm(viewModel: GroupViewModel(currentUser: nil, useDevMode: true))
}