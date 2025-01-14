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


class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        FirebaseApp.configure()
    }
}


@main
struct halfhazardApp: App {
    // register app delegate for Firebase setup
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate


    var body: some Scene {
      WindowGroup {
        NavigationView {
          ContentView()
        }
      }
    }
}
