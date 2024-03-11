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
    
    @Bindable var item: Expense
    
    var body: some View {
        List {
            TextField("Name", text: $item.name)
            TextField("Double", value: $item.amount, format: .number)
            Button("Update") {
                dismiss()
            }
        }
        .navigationTitle("Edit Expense")
    }
}
