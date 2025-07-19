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
    @StateObject private var appNavigation = AppNavigation()
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
        
        // Platform-specific initialization
        #if os(macOS)
        configureMacOS()
        #elseif os(iOS)
        configureIOS()
        #endif
        
        // Check if Auth is configured
        print("Auth current user: \(String(describing: Auth.auth().currentUser))")
    }
    
    #if os(macOS)
    private func configureMacOS() {
        // Add keychain workaround for macOS development
        do {
            if let authOptions = Auth.auth().settings {
                authOptions.appVerificationDisabledForTesting = true
            }
            try Auth.auth().useUserAccessGroup(nil)
        } catch let error as NSError {
            print("Error setting up Auth user access group: \(error)")
        }
    }
    #elseif os(iOS)
    private func configureIOS() {
        // iOS-specific Firebase initialization if needed
        if let authOptions = Auth.auth().settings {
            authOptions.appVerificationDisabledForTesting = true
        }
    }
    #endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appNavigation)
                #if os(iOS)
                .preferredColorScheme(.light) // Default to light mode on iOS
                .statusBar(hidden: true) // Hide status bar
                #endif
        }
        #if os(macOS)
        .windowStyle(HiddenTitleBarWindowStyle()) // macOS-specific window style
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Expense") {
                    appNavigation.showCreateExpenseForm()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("New Group") {
                    appNavigation.showCreateGroupForm()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("Join Group") {
                    appNavigation.showJoinGroupForm()
                }
                .keyboardShortcut("j", modifiers: .command)
            }
        }
        #endif
    }
}
