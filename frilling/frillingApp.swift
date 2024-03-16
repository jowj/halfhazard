// I have no idea what this is for.
//  frillingApp.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI
import SwiftData

@main
struct frillingApp: App {
    
    @AppStorage("isFirstTimeLaunch") private var isFirstTimeLaunch: Bool = true
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // important for SwiftData? I'm watching this video that says to do this.
                // maybe its right?
                .modelContainer(ExpensesContainer.create(shouldCreateDefaults: &isFirstTimeLaunch))
        }
    }
}
