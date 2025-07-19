//
//  JoinGroupForm.swift
//  halfhazard
//
//  Created by Claude on 2025-04-01.
//

import SwiftUI
import FirebaseFirestore

struct JoinGroupForm: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: GroupViewModel
    @State private var isSubmitting = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Join Group")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 12) {
                // Group Code field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Code")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter the group code", text: $viewModel.joinGroupCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
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
                    if let appNav = viewModel.appNavigationRef {
                        appNav.navigateBack()
                    } else {
                        dismiss()
                    }
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Join Group") {
                    Task {
                        isSubmitting = true
                        await viewModel.joinGroup()
                        isSubmitting = false
                        
                        // Only handle sheet dismissal if we don't have AppNavigation
                        if viewModel.errorMessage == nil && viewModel.appNavigationRef == nil {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.joinGroupCode.isEmpty || isSubmitting)
                .keyboardShortcut(.return, modifiers: .command)
                .overlay {
                    if isSubmitting {
                        ProgressView()
                    }
                }
            }
            .padding()
        }
        .frame(width: 400, height: 250)
        .onAppear {
            // Clear any previous error messages when the form appears
            viewModel.errorMessage = nil
        }
    }
}

#Preview {
    JoinGroupForm(viewModel: GroupViewModel(currentUser: nil, useDevMode: true))
}