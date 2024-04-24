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
    @State var selectedGroup: Group?
    
    @Query private var categories: [ExpenseCategory]
    @Query private var users: [User]
    @Query private var groups: [Group]
        
    var body: some View {
        VStack {
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
                
                if groups.isEmpty {
                    ContentUnavailableView("No groups exist. Go make some!",
                    systemImage: "archivebox")
                } else {
                    Section("What group is the expense related to?") {
                        Picker("", selection: $selectedGroup) {
                            
                            Text("None")
                                .tag(nil as Group?) // I don't understand this but copied from a tutorial
                            ForEach(groups) {group in
                                Text(group.name)
                                    .tag(group as Group?) // same as above, waht is this
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
        item.group = selectedGroup
    }
    
}

