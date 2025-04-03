//
//  DevAuthService.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import Foundation
import FirebaseFirestore

/// A development-only authentication service that bypasses Firebase Authentication
/// Use this for development when you encounter keychain access issues
class DevAuthService {
    private static var instance: DevAuthService?
    
    static var shared: DevAuthService {
        if instance == nil {
            instance = DevAuthService()
        }
        return instance!
    }
    
    private var isAuthenticated = false
    private var currentUser: User?
    
    // Reset between app launches
    init() {
        print("DevAuthService initialized")
    }
    
    func signIn(email: String, password: String) -> User? {
        // In development, we'll accept any valid-looking email and password
        if email.contains("@") && password.count >= 6 {
            let userID = "dev-\(email.hash)"
            let user = User(
                uid: userID,
                displayName: email.components(separatedBy: "@").first,
                email: email,
                groupIds: [],
                createdAt: Timestamp(),
                lastActive: Timestamp()
            )
            
            isAuthenticated = true
            currentUser = user
            return user
        }
        return nil
    }
    
    func getCurrentUser() -> User? {
        return isAuthenticated ? currentUser : nil
    }
    
    func signOut() {
        isAuthenticated = false
        currentUser = nil
    }
}