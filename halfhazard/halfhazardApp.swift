// I have no idea what this is for.
//  halfhazardApp.swift
//
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI
import SwiftData

@main
struct halfhazard: App {
    @State private var navigationPath = NavigationPath()
    @AppStorage("isFirstTimeLaunch") private var isFirstTimeLaunch: Bool = true
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Expense.self,
            User.self,
            Group.self,
            ExpenseCategory.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView(navigationPath: $navigationPath)
                // important for SwiftData? I'm watching this video that says to do this.
                // maybe its right?
                .modelContainer(sharedModelContainer)
        }
    }
}

extension ModelContext {
    // This is useul for printing out or programmatically accessing your idiot sqlite db.
    var sqliteCommand: String {
        if let url = container.configurations.first?.url.path(percentEncoded: false) {
            "sqlite3 \"\(url)\""
        } else {
            "No SQLite database found."
        }
    }
}

