//
//  ExpenseView.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-02-26.
//

import SwiftUI

struct ExpenseView: View {
    var expense: Expense
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(expense.name)
                .foregroundColor(.primary)
                .font(.headline)
            HStack(spacing: 3) {
                Label("\(expense.amount)" , systemImage: "dollarsign")
            }
            .foregroundColor(.secondary)
            .font(.subheadline)
        }
    }
}


//#Preview {
//    ExpenseView()
//}
