//
//  CreateGroupForm.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import SwiftUI
import FirebaseFirestore
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct CreateGroupForm: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: GroupViewModel
    
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isSubmitting = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Create New Group")
                .font(.headline)
                .padding(.top)
                
            VStack(alignment: .leading, spacing: 12) {
                // Group Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter a name for your group", text: $groupName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: groupName) { oldValue, newValue in
                            viewModel.newGroupName = newValue
                        }
                }
                .padding(.bottom, 8)
                
                // Description field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter a description", text: $groupDescription)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: groupDescription) { oldValue, newValue in
                            viewModel.newGroupDescription = newValue
                        }
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action Buttons
            HStack {
                Button("Cancel") {
                    // If we have an AppNavigation reference, use it
                    if let appNav = viewModel.appNavigationRef {
                        appNav.navigateBack()
                    } else {
                        // Fall back to Environment dismiss for sheet presentation
                        dismiss()
                    }
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create Group") {
                    Task {
                        isSubmitting = true
                        await viewModel.createGroup()
                        isSubmitting = false
                        
                        // Only dismiss if there's no error message
                        if viewModel.errorMessage == nil {
                            // The navigation back is handled in the viewModel.createGroup() method
                            // But we still need to handle sheet dismissal if we don't have AppNavigation
                            if viewModel.appNavigationRef == nil {
                                dismiss()
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(groupName.isEmpty || isSubmitting)
                .keyboardShortcut(.return, modifiers: .command)
                .overlay {
                    if isSubmitting {
                        ProgressView()
                    }
                }
            }
            .padding()
        }
        .frame(width: 400, height: 320)
        .onAppear {
            // Initialize form fields from viewModel
            groupName = viewModel.newGroupName
            groupDescription = viewModel.newGroupDescription
            
            // Clear any previous error messages when the form appears
            viewModel.errorMessage = nil
        }
    }
}

#Preview {
    CreateGroupForm(viewModel: GroupViewModel(currentUser: nil, useDevMode: true))
}