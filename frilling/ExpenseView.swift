//
//  ExpenseView.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-26.
//

import SwiftUI

var expenseList = [
    Expense(name: "Lunch", amount: 500, status: "incomplete"),
    Expense(name: "Dinner", amount: 90, status: "incomplete")
]

struct ExpenseView: View {
    var expense: Expense
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(expense.name)
                .foregroundColor(.primary)
                .font(.headline)
            HStack(spacing: 3) {
                Label("\(expense.amount)" , systemImage: "money")
            }
            .foregroundColor(.secondary)
            .font(.subheadline)
        }
    }
}


//#Preview {
//    ExpenseView()
//}
