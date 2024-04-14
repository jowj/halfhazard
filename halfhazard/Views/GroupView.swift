//
//  GroupView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-04-14.
//

import SwiftUI
import SwiftData



struct GroupView: View {
    @AppStorage("userID") var userID: String = ""
    
    @State private var expenseEdit: Expense?
    @State private var searchQuery = ""
    @State public var selectedGroup: Group
    
    @Query private var groups: [Group]
    @Query private var items: [Expense]
    @Query private var users: [User]
    
    @Environment(\.modelContext) var context
    
    var filteredExpenses: [Expense] {
        /* Given a group (provided by parent View), return a list of expenses assosciated with that group's name.
         Otherwise, return an empty list of [Expense].
         */
        var filteredExpenses: [Expense] = [Expense]()
        for group in groups {
            if group.name == selectedGroup.name {
                if (group.expenses?.isEmpty) != nil {
                    for expense in group.expenses ?? [Expense]() {
                        if expense.group?.name == group.name {
                            filteredExpenses.append(expense)
                        }
                        return filteredExpenses
                    }
                } else {
                    return [Expense]()
                }
            }
        }
        return [Expense]()
    }
    
    
    
    var body: some View {
        List {
            // This ForEach shows each Expense and some buttons.
            ForEach(filteredExpenses) { item in
                HStack {
                    ExpenseView(expense: item)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    context.delete(item)
                                    
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .symbolVariant(.circle.fill)
                            }
                            .tint(.orange)
                            
                            Button(role: .cancel) {
                                withAnimation {
                                    expenseEdit = item
                                }
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .symbolVariant(.circle.fill)
                            }
                            
                            Button(role: .none) {
                                withAnimation {
                                    item.isCompleted.toggle()
                                }
                            } label: {
                                Label("Mark complete", systemImage: "checkmark")
                                    .symbolVariant(.circle.fill)
                                    .foregroundStyle(item.isCompleted ? .green :
                                            .gray)
                            }
                        }
                }
            }
        }
            
    }
}
