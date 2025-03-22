//
//  halfhazardApp.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-12.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

@main
struct halfhazardApp: App {
    init() {
        print("Configuring Firebase...")
        
        // Print GoogleService-Info.plist contents for debug
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            print("GoogleService-Info.plist contents:")
            for (key, _) in dict {
                print("  - \(key): [REDACTED]")
            }
        } else {
            print("WARNING: GoogleService-Info.plist not found or couldn't be read!")
        }
        
        // Configure Firebase first
        FirebaseApp.configure()
        print("Firebase configured successfully")
        
        // Add keychain workaround for development
        do {
            if let authOptions = Auth.auth().settings {
                authOptions.appVerificationDisabledForTesting = true
            }
            try Auth.auth().useUserAccessGroup(nil)
        } catch let error as NSError {
            print("Error setting up Auth user access group: \(error)")
        }
        
        // Check if Auth is configured
        print("Auth current user: \(String(describing: Auth.auth().currentUser))")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
