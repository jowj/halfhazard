//
//  halfhazard_iosApp.swift
//  halfhazard_ios
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

@main
struct halfhazard_iosApp: App {
    init() {
        print("Configuring Firebase for iOS...")
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Add keychain workaround for iOS development
        if let authOptions = Auth.auth().settings {
            authOptions.appVerificationDisabledForTesting = true
        }
    }
    
    var body: some Scene {
        WindowGroup {
            iOSContentView()
        }
    }
}
