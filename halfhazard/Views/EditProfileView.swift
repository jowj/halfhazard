//
//  EditProfileView.swift
//  halfhazard
//
//  Created by Claude on 2025-04-08.
//

import SwiftUI
import FirebaseFirestore

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    let userService: UserService
    let user: User
    
    @State private var displayName: String
    @State private var email: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // We need a separate binding for the alert to work correctly
    var showError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
    
    init(userService: UserService, user: User) {
        self.userService = userService
        self.user = user
        _displayName = State(initialValue: user.displayName ?? "")
        _email = State(initialValue: user.email)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Profile")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Display Name", text: $displayName)
                    .disableAutocorrection(true)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 8)
                
                Text("Email Address")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Email", text: $email)
                    .disableAutocorrection(true)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    #endif
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: saveProfile) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Save Changes")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || !isValidInput)
            }
            .padding()
        }
        .frame(width: 350, height: 250)
        .disabled(isLoading)
        .alert("Error", isPresented: showError) {
            Button("OK", action: {})
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
    }
    
    private var isValidInput: Bool {
        return !displayName.isEmpty && isValidEmail(email)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func saveProfile() {
        isLoading = true
        
        Task {
            do {
                _ = try await userService.updateUserProfile(displayName: displayName, email: email)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to update profile: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    let user = User(
        uid: "preview-user-id",
        displayName: "Preview User",
        email: "preview@example.com",
        groupIds: [],
        createdAt: Timestamp(),
        lastActive: Timestamp()
    )
    
    return EditProfileView(userService: UserService(), user: user)
}