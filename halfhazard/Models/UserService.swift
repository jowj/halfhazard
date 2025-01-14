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
class UserService {
    let auth = Auth.auth()
    let db = Firestore.firestore()
    
    func signIn(email: String, password: String) async throws -> User {
        let result = try await auth.signIn(withEmail: email, password: password)
        return try await getUser(uid: result.user.uid)
    }
    
    func createUser(email: String, password: String, displayName: String?) async throws -> User {
        let result = try await auth.createUser(withEmail: email, password: password)
        
        let user = User(
            uid: result.user.uid,
            displayName: displayName,
            email: email,
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        try await db.collection("users").document(user.uid).setData(from: user)
        return user
    }
    
    func getUser(uid: String) async throws -> User {
        return try await db.collection("users").document(uid).getDocument(as: User.self)
    }
}
