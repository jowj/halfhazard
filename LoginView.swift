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
    
    @AppStorage("email") var email: String = ""
    @AppStorage("fullName") var fullName: String = ""
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
                            // Actually important!!
                            let userID = cred.user
                            
                            // Just misc stuff, but if you don't save it after they auth one time you never get it again!!
                            // Store in your DB.
                            let email = cred.email
                            let fullName = cred.fullName
                            
                            // assigns these values to local storage, which is important, i guess?
                            // I'm also coalescening here, which is useful for User init, I suppose.
                            self.email = email ?? ""
                            self.userID = userID
                            self.fullName = fullName ?? ""
                            
                            //init a user obj
                            User(userID: userID, emailAddress: email, fullName: fullName)
                            
                        default:
                            break
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
                        email = ""
                        firstName = ""
                        lastName = ""
                        userID = ""
                        // There HAS to be a better way of reasoning about this, right??
                        // Like, just setting everythign to empty string CAN'T be correct?
                    }
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        .symbolVariant(.circle.fill)
                }

            }
            
            Spacer()

            .frame(height: 50)
            .padding()
            .cornerRadius(8)
        }
        .navigationTitle("Account Info")
    }
}
    



#Preview {
    LoginView()
}
