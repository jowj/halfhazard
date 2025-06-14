//
//  UserService.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-13.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// this is from claude direct, I need to futz with this
import Combine

class UserService: ObservableObject {
    // Reference to the ExpenseViewModel for use by other views
    var expenseViewModel: ExpenseViewModel?
   let auth = Auth.auth()
   let db = Firestore.firestore()
   
   func signIn(email: String, password: String) async throws -> User {
       let authResult = try await auth.signIn(withEmail: email, password: password)
       
       do {
           // Try to get the user document
           return try await getUser(uid: authResult.user.uid)
       } catch {
           // If user document doesn't exist in Firestore, create it
           print("User document not found, creating a new one")
           
           let user = User(
               uid: authResult.user.uid,
               displayName: authResult.user.displayName,
               email: email,
               groupIds: [],
               createdAt: Timestamp(),
               lastActive: Timestamp()
           )
           
           // Save user to Firestore
           try db.collection("users").document(user.uid).setData(from: user)
           
           return user
       }
   }
   
   func signOut() throws {
       try auth.signOut()
   }
   
   func createUser(email: String, password: String, displayName: String?) async throws -> User {
       let authResult = try await auth.createUser(withEmail: email, password: password)
       
       let user = User(
           uid: authResult.user.uid,
           displayName: displayName,
           email: email,
           groupIds: [],
           createdAt: Timestamp(),
           lastActive: Timestamp()
       )
       
       try db.collection("users").document(user.uid).setData(from: user, merge: true)

       return user
   }
   
   func getUser(uid: String) async throws -> User {
       let documentSnapshot = try await db.collection("users").document(uid).getDocument()
       
       if documentSnapshot.exists {
           return try documentSnapshot.data(as: User.self)
       } else {
           throw NSError(
               domain: "UserService",
               code: 404,
               userInfo: [NSLocalizedDescriptionKey: "User document does not exist in Firestore"]
           )
       }
   }
   
   func updateUser(_ user: User) async throws {
       try db.collection("users").document(user.uid).setData(from: user)
   }
   
   func updateUserProfile(displayName: String?, email: String?) async throws -> User? {
       guard let currentUser = auth.currentUser else {
           throw NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
       }
       
       // Update Firebase Auth profile if display name is provided
       if let displayName = displayName, displayName != currentUser.displayName {
           let changeRequest = currentUser.createProfileChangeRequest()
           changeRequest.displayName = displayName
           try await changeRequest.commitChanges()
       }
       
       // Update email if provided and different from current
       if let email = email, email != currentUser.email {
           try await currentUser.updateEmail(to: email)
       }
       
       // Now also update the Firestore document
       let user = try await getUser(uid: currentUser.uid)
       var updatedUser = user
       if let displayName = displayName {
           updatedUser.displayName = displayName
       }
       if let email = email, email != user.email {
           updatedUser.email = email
       }
       updatedUser.lastActive = Timestamp()
       try await updateUser(updatedUser)
       
       // Return updated user information
       return try await getCurrentUser()
   }
   
   func deleteUser(uid: String) async throws {
       try await db.collection("users").document(uid).delete()
       try await auth.currentUser?.delete()
   }
    func getCurrentUser() async throws -> User? {
        guard let currentUser = auth.currentUser else { return nil }
        
        do {
            return try await getUser(uid: currentUser.uid)
        } catch {
            // If user document doesn't exist in Firestore but Firebase Auth has a user,
            // create the user document
            print("Current user document not found, creating a new one")
            
            let user = User(
                uid: currentUser.uid,
                displayName: currentUser.displayName,
                email: currentUser.email ?? "unknown@email.com",
                groupIds: [],
                createdAt: Timestamp(),
                lastActive: Timestamp()
            )
            
            // Save user to Firestore
            try db.collection("users").document(user.uid).setData(from: user)
            
            return user
        }
    }
}
