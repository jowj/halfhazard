//
//  CreateExpenseView.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-03-11.
//

import SwiftUI

struct CreateExpenseView: View {
    
    @FocusState private var costIsFocused: Bool
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @State private var item = Expense()

    
    var body: some View {
        List {
            Form {
                Section {
                    TextField("Name", text: $item.name)
                    TextField("Cost", value: $item.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                }
            }
            
            Button("create") {
                withAnimation {
                    context.insert(item)
                }
                dismiss()
            }
        }
        .navigationTitle("Add an expense")
    }
}

#Preview {
    CreateExpenseView()
        .modelContainer(for: Expense.self)
}

