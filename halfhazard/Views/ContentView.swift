// This contains the *primary*, default view of the app.
//  ContentView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    // you THINK you are re-initiatlizing variables, but because of how @AppStorage works you're not!
    // Anytime you want to ref an appstorage var you "reinit" just like this.
    @AppStorage("email") var email: String = ""
    @AppStorage("fullName") var fullName: String = ""
    @AppStorage("userID") var userID: String = ""

    @Environment(\.modelContext) var context
    var loggedIn = false
    
    var body: some View {
        if userID.isEmpty {
            LoginView()
        } else {
            HomeView()
        }
    }
}

#Preview {
    ContentView()
}

