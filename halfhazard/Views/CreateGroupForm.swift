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
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Create New Group")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Create a group to start tracking expenses with friends or colleagues")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            // Form
            Form {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Name").font(.headline)
                        TextField("Enter a name for your group", text: $groupName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: groupName) { oldValue, newValue in
                                viewModel.newGroupName = newValue
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (Optional)").font(.headline)
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
                
                Button("Create Group") {
                    Task {
                        isSubmitting = true
                        await viewModel.createGroup()
                        isSubmitting = false
                        
                        // Only dismiss if there's no error message
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(groupName.isEmpty || isSubmitting)
                .keyboardShortcut(.defaultAction)
                .overlay {
                    if isSubmitting {
                        ProgressView()
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 450, minHeight: 350)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
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