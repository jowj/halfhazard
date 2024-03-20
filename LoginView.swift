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
    @AppStorage("firstName") var firstName: String = ""
    @AppStorage("lastName") var lastName: String = ""
    @AppStorage("userID") var userID: String = ""
    
    var body: some View {
        VStack {
            Text("Login. or don't. i'm not your mom.!")
            
            Spacer()
            
//            Table(of: user.self) {
//                TableColumn("user id") {
//                    Text(
//                }
//            }
            
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
                        let firstName = cred.fullName?.givenName
                        let lastName = cred.fullName?.familyName
                        
                        // assigns these values to local storage, which is important, i guess?
                        self.email = email ?? ""
                        self.userID = userID
                        self.firstName = firstName ?? ""
                        self.lastName = lastName ?? ""
                        
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
            .frame(height: 50)
            .padding()
            .cornerRadius(8)
        }
        .navigationTitle("Sign In")
    }
}
    



#Preview {
    LoginView()
}
