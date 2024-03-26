//
//  CreateExpenseView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-03-11.
//

import SwiftUI
import SwiftData

struct CreateExpenseView: View {
    
    @AppStorage("name") var name: String = ""
    @AppStorage("userID") var userID: String = ""
    
    @FocusState private var costIsFocused: Bool
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    
    @State private var item = Expense()
    @State var selectedCategory: ExpenseCategory?
    
    @Query private var categories: [ExpenseCategory]
    @Query private var users: [User]
        
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
        .toolbar {
            
            ToolbarItem(placement: .cancellationAction) {
                Button("Dismiss") {
                    dismiss()
                }
            }
        }

    }
}

private extension CreateExpenseView {
    
    func save() {
        context.insert(item)
        item.category = selectedCategory
        item.author = currentUser(users: users, currentUserID: userID)
        selectedCategory?.items?.append(item)
    }
    
    func currentUser (users: [User], currentUserID: String) -> User {
        // Return the currently logged in user if the currentUserID field is not empty.
        // If it is, just return the first user.
        // A recipe for bugs if i ever found one.
        guard !currentUserID.isEmpty else { return users[0] } // THIS IS A DUMB HACK THAT SHOULD BREAK.
        return users.filter { user in
            user.id == currentUserID
        }[0]
    }
}

