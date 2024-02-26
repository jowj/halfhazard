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
    @State var expenseList: [Expense] = []
    
    @FocusState private var costIsFocused: Bool

    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $newExpenseName)
                    TextField("Cost", value: $newExpenseCost, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                }
            }
            
            Button(action: addExpense) {
                Label("Add Expense", systemImage: "dollarsign")
            }
        }
        List {
            ForEach(expenseList) { expense in
                ExpenseView(expense: expense)
            }
        }

    }
    
    func addExpense() {
        let expense = Expense(name: newExpenseName, amount: newExpenseCost, status: newExpenseStatus)
        expenseList.append(expense)
    }
}

#Preview {
    ContentView()
}

