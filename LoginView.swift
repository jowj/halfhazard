//
//  LoginView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-03-19.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
     
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var context

    @AppStorage("email") var email: String = ""
    @AppStorage("userID") var userID: String = ""
        
    var body: some View {
        VStack {
            if userID.isEmpty {
                Text("Login. or don't. i'm not your mom.!")

                Spacer()
                
                SignInWithAppleButton(.continue) { request in
                    
                    request.requestedScopes = [.email, .fullName]
                    
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        switch auth.credential {
                        case let cred as ASAuthorizationAppleIDCredential:
                            save(credential: cred)
                        default:
                            print("its not working")
                        }
                    case .failure(let error):
                        print(error)
                    }
                }
                .signInWithAppleButtonStyle(
                    colorScheme == .dark ? .white : .black
                )
            } else {
                Text("You are logged in!")
                List {
                    Text("UserID is \(userID)")
                    Text("email is \(email)")
                }
                Button(role: .destructive) {
                    withAnimation {
                        // As far as I can tell, apple offers no logout button, so if I want the user to be able to logout
                        // then i need to just, de-initialize all their related state.
                        // super weird.
                        email = ""
                        userID = ""
                    }
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        .symbolVariant(.circle.fill)
                }

            }
        }
        .navigationTitle("Sign In")
    }
}
    
private extension LoginView{
    func save(credential: ASAuthorizationAppleIDCredential) {
        // Actually important!!
        // Just misc stuff, but if you don't save it after they auth one time you never get it again!!
        // Store in your DB.
        let userID = credential.user
        let email = credential.email

        // assigns these values to local storage, which is important, i guess?
        self.email = email ?? ""
        self.userID = userID
    }
}


#Preview {
    LoginView()
}
