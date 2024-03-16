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
