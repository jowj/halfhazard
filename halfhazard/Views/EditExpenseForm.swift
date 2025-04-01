//
//  EditExpenseForm.swift
//  halfhazard
//
//  Created by Claude on 2025-03-25.
//

import SwiftUI
import FirebaseFirestore

struct EditExpenseForm: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ExpenseViewModel
    
    @State private var amount = ""
    @State private var description = ""
    @State private var splitType: SplitType
    
    init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
        
        // Initialize state from the editing expense
        let expenseAmount = viewModel.newExpenseAmount
        _amount = State(initialValue: expenseAmount > 0 ? String(format: "%.2f", expenseAmount) : "")
        _description = State(initialValue: viewModel.newExpenseDescription)
        _splitType = State(initialValue: viewModel.newExpenseSplitType)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Expense Details")) {
                // Amount field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Amount").font(.headline)
                    TextField("0.00", text: $amount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
                Button("Save Changes") {
                    Task {
                        await viewModel.saveEditedExpense()
                        // Navigation is handled in the viewModel
                    }
                }
                .disabled(amount.isEmpty || !isValidAmount(amount))
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Edit Expense")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if !viewModel.navigationPath.isEmpty {
                        viewModel.navigationPath.removeLast()
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            // Make sure form is initialized from viewModel
            if viewModel.newExpenseAmount > 0 && amount.isEmpty {
                amount = String(viewModel.newExpenseAmount)
            }
            if description.isEmpty {
                description = viewModel.newExpenseDescription
            }
            splitType = viewModel.newExpenseSplitType
        }
    }
    
    private func isValidAmount(_ amount: String) -> Bool {
        guard let value = Double(amount) else { return false }
        return value > 0
    }
}

#Preview {
    EditExpenseForm(viewModel: ExpenseViewModel(currentUser: nil))
}