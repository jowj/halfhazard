//
//  CreateExpenseView.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-03-11.
//

import SwiftUI
import SwiftData

struct CreateExpenseView: View {
    
    @FocusState private var costIsFocused: Bool
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    
    @State private var item = Expense()
    @State var selectedCategory: ExpenseCategory?
    @Query private var categories: [ExpenseCategory]
    
    var body: some View {
        List {
            Form {
                Section("What did you spend money on?") {
                    TextField("Name", text: $item.name)
                }
                Section("How much did it cost?") {
                    TextField("Cost", value: $item.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                }
                
                if categories.isEmpty {
                    ContentUnavailableView("No categories exist.",
                    systemImage: "archivebox")
                } else {
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
            }
            
            Button("create") {
                save()
                dismiss()
            }
        }
        .navigationTitle("Add an expense")
    }
}

private extension CreateExpenseView {
    func save() {
        context.insert(item)
        item.category = selectedCategory
        selectedCategory?.items?.append(item)
    }
}

#Preview {
    CreateExpenseView()
        .modelContainer(for: Expense.self)
}

