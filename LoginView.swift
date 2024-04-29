//
//  LoginView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-03-19.
//

import SwiftUI
import AuthenticationServices
import SwiftData

struct LoginView: View {
     
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var context
    
    @Query private var users: [User]
    @AppStorage("name") var name: String = ""
    @AppStorage("userID") var userID: String = ""
        
    var currentUserFromDB: User {
        currentUser(users: users, currentUserID: userID)
    }
    
    var filteredGroups: [Group] {
        let currentUser = currentUser(users: users, currentUserID: userID)
        if let userGroups = currentUser.groups {
            return userGroups
        } else {
            return [Group]()
        }
    }

    var body: some View {
        VStack {
            if userID.isEmpty {
                
                Spacer()

                Text("You have to log in or the app won't work!")
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
                
                Spacer()

            } else {
                VStack {
                    Text("You are logged in!")
                    List {
                        Text("UserID is \(userID)")
                        Text("Username is \(name)")
                        
                        Section("Configure your username") {
                            TextField("", text: $name)
                            Button("Update") {
                                currentUserFromDB.name = name
                            }

                        }
                        Section("You are a member of the following groups:") {
                            ForEach(filteredGroups) { group in
                                Text(group.name)
                            }
                        }
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
                    .tint(.red)
                }

            }
        }
        .navigationTitle("Account Management")
    }
}
    
private extension LoginView{
    func save(credential: ASAuthorizationAppleIDCredential) {
        var exists = false
        for user in users {
            if credential.user == user.userID {
                // This handles the "you have logged in before and I don't need to insert, I just need to /load/.
                let currentUser = user
                // GOD this unwrapping thing is so annoying.
                if let existingname = currentUser.name {
                    name = existingname
                }
                userID = currentUser.userID
                exists = true
                break
            }
        }
        // This handles the "you haven't logged in before and we have to make a new user for you" flow.
        if exists == true {
            print("holy shit you already exist! i shouldn't insert you again!")
            return
        } else {
            print("Never found an existing user, lets make a new one.")
            let userID = credential.user
            let currentUser = User(userID: userID, name: name)
            context.insert(currentUser)
            
            // Put stuff in local storage
            currentUser.name = name
            currentUser.userID = userID

        }
    }
}
