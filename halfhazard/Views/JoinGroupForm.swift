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
                    // If we're in a navigation stack, go back
                    if !viewModel.navigationPath.isEmpty {
                        viewModel.navigationPath.removeLast()
                    } else {
                        // Fall back to Environment dismiss for sheet presentation
                        dismiss()
                    }
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Join Group") {
                    Task {
                        isSubmitting = true
                        await viewModel.joinGroup()
                        isSubmitting = false
                        
                        // Only navigate back if there's no error message
                        if viewModel.errorMessage == nil {
                            // The navigation back is handled in the viewModel.joinGroup() method
                            // But we still need to handle sheet dismissal if we're in a sheet
                            if viewModel.navigationPath.isEmpty {
                                dismiss()
                            }
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