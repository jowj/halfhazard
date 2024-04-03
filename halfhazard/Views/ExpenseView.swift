//
//  ExpenseView.swift
//  halfhazard
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
                Label("\(expense.amount.formatted(.currency(code: "USD")))" , systemImage: "dollarsign.square.fill")
            }
            .foregroundColor(.secondary)
            .font(.subheadline)
            
            if let author = expense.author?.id {
                HStack(spacing: 3) {
                    Label("\(author)" , systemImage: "person.crop.square.fill")
                }
                .foregroundColor(.secondary)
                .font(.subheadline)
            }
            
            if let category = expense.category {
                Text(category.title)
            }
            
            if let amountOwed = expense.amountOwed {
                Text("You owe \(amountOwed.formatted(.currency(code: "USD")))")
                    .font(.subheadline)
                    .underline(color: Color("red")) // this doesn't appear to work, but seems like it should?

            }


        }
    }
}


//#Preview {
//    ExpenseView()
//}
