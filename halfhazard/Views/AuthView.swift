//
//  AuthView.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import SwiftUI

struct AuthView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var displayName: String
    @Binding var isRegistering: Bool
    @Binding var useDevMode: Bool
    
    let signInAction: () async -> Void
    let registerAction: () async -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Halfhazard")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(isRegistering ? "Create a new account" : "Sign in to your account")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 15) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if isRegistering {
                    TextField("Display Name", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                }
            }
            .frame(maxWidth: 300)
            
            Button(isRegistering ? "Register" : "Sign In") {
                Task {
                    if isRegistering {
                        await registerAction()
                    } else {
                        await signInAction()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || (isRegistering && displayName.isEmpty))
            
            Button(isRegistering ? "Already have an account? Sign In" : "Don't have an account? Register") {
                isRegistering.toggle()
            }
            .buttonStyle(.plain)
            .font(.footnote)
            
            // Dev mode option
            Toggle("Development Mode (Bypass Firebase Auth)", isOn: $useDevMode)
                .padding(.top, 20)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: 400, maxHeight: 600)
    }
}

#Preview {
    AuthView(
        email: .constant("test@example.com"),
        password: .constant("password"),
        displayName: .constant("Test User"),
        isRegistering: .constant(false),
        useDevMode: .constant(false),
        signInAction: { },
        registerAction: { }
    )
}