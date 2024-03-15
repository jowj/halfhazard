//
//  EditExpenseView.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-03-11.
//

import SwiftUI
import SwiftData

struct EditExpenseView: View {
    
    @Environment(\.dismiss) var dismiss
    
    @State var selectedCategory: ExpenseCategory?
    @Query private var categories: [ExpenseCategory]

    @Bindable var item: Expense
    
    var body: some View {
        List {
            Form {
                Section("What did you spend money on?") {
                    TextField("Name", text: $item.name)
                }
                Section("How much did it cost?") {
                    TextField("Cost", value: $item.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                }

                Section("What kind of expense is it?") {
                    Picker("", selection: $selectedCategory) {
                        
                        Text("None")
                            .tag(nil as ExpenseCategory?) // I don't understand this but copied from a tutorial
                        ForEach(categories) {category in
                            Text(category.title)
                                .tag(category as ExpenseCategory?) // same as above, waht is this
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                }
            }

            Button("Update") {
                dismiss()
            }
        }
        .navigationTitle("Edit Expense")
    }
}
