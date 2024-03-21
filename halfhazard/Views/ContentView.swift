// This contains the *primary*, default view of the app.
//  ContentView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    @Environment(\.modelContext) var context
        
    var body: some View {
        if //userID.isempty {
            LoginView()
        } else {
            HomeView()
        }
    }
}

#Preview {
    ContentView()
}

