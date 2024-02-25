//
//  ContentView.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-24.
//

import SwiftUI

struct ContentView: View {
    @State var newExpense: String = ""
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
                text: $newExpense)
        }
        
        Section("Expenses") {
            Text(newExpense)
        }
    }
}

#Preview {
    ContentView()
}
