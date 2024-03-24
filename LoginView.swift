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
    
    @AppStorage("name") var name: String = ""
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
                VStack {
                    Text("You are logged in!")
                    List {
                        Text("UserID is \(userID)")
                        Text("name is \(name)")
                    }
                    Button(role: .destructive) {
                        withAnimation {
                            // As far as I can tell, apple offers no logout button, so if I want the user to be able to logout``
                            // then i need to just, de-initialize all their related state.
                            // super weird.
                            name = ""
                            userID = ""
                        }
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                            .symbolVariant(.circle.fill)
                    }
                }

            }
        }
        .navigationTitle("Account Management")
    }
}
    
private extension LoginView{
    func save(credential: ASAuthorizationAppleIDCredential) {
        
        let userID = credential.user
        let name = credential.fullName?.givenName ?? ""


        let currentUser = User(id: userID, name: name)
        context.insert(currentUser)
        
        // Put stuff in local storage
        self.name = name
        self.userID = userID
    }
}


#Preview {
    LoginView()
}
