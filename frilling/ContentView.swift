// This contains the *primary*, default view of the app.
//  ContentView.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI

struct ContentView: View {
    @State var newExpenseName: String = ""
    @State var newExpenseCost: Double = 0.0
    @State var newExpenseUser: String = "Josiah" // probably should just make this default to Josiah or something for testing?
    @State var newExpenseGroup: String = "Sainthood" // Using sainthood for testing
    @State var newExpenseStatus: String = "Incomplete" // Should be an enum thing, probably
    @State var expenseList: [String] = []
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        // Figure out how the fuck to make a new text field.
        Section("New Expense!") {
            TextField(
                "What did you pay for?",
                text: $newExpenseName)
            TextField(
                "How much did it cost?",
                text: $newExpenseCost, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
            TextField(
                "What did you pay for?",
                text: $newExpenseName)

        }
        
        List {
            Section("Expenses") {
                Text(newExpenseName)
            }
        }
    }
}

#Preview {
    ContentView()
}
