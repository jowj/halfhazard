//
//  CreateExpenseForm.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import SwiftUI
import FirebaseFirestore

struct CreateExpenseForm: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ExpenseViewModel
    
    @State private var amount = ""
    @State private var description = ""
    @State private var splitType = SplitType.equal
    
    var body: some View {
        Form {
            Section(header: Text("Expense Details")) {
                // Amount field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Amount").font(.headline)
                    TextField("0.00", text: $amount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        // macOS doesn't support keyboardType
                        .onChange(of: amount) { oldValue, newValue in
                            if let amountDouble = Double(newValue) {
                                viewModel.newExpenseAmount = amountDouble
                            } else {
                                viewModel.newExpenseAmount = 0
                            }
                        }
                }
                .padding(.vertical, 4)
                
                // Description field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description").font(.headline)
                    TextField("What was this expense for?", text: $description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: description) { oldValue, newValue in
                            viewModel.newExpenseDescription = newValue
                        }
                }
                .padding(.vertical, 4)
                
                // Split type selector
                VStack(alignment: .leading, spacing: 6) {
                    Text("Split Type").font(.headline)
                    Picker("Split Type", selection: $splitType) {
                        Text("Equal").tag(SplitType.equal)
                        Text("Percentage").tag(SplitType.percentage)
                        Text("Custom").tag(SplitType.custom)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: splitType) { oldValue, newValue in
                        viewModel.newExpenseSplitType = newValue
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section {
                Button("Create Expense") {
                    Task {
                        await viewModel.createExpense()
                        dismiss()
                    }
                }
                .disabled(amount.isEmpty || !isValidAmount(amount))
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Add Expense")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            // Initialize form fields from viewModel
            if viewModel.newExpenseAmount > 0 {
                amount = String(viewModel.newExpenseAmount)
            }
            description = viewModel.newExpenseDescription
            splitType = viewModel.newExpenseSplitType
        }
    }
    
    private func isValidAmount(_ amount: String) -> Bool {
        guard let value = Double(amount) else { return false }
        return value > 0
    }
}

#Preview {
    CreateExpenseForm(viewModel: ExpenseViewModel(currentUser: nil))
}