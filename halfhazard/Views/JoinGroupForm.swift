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
        .frame(minWidth: 400, minHeight: 280)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .onAppear {
            // Clear any previous error messages when the form appears
            viewModel.errorMessage = nil
        }
    }
}

#Preview {
    JoinGroupForm(viewModel: GroupViewModel(currentUser: nil, useDevMode: true))
}