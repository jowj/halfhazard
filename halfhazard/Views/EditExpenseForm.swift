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
        VStack(spacing: 16) {
            Text("Edit Expense")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 12) {
                // Amount field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
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
                .padding(.bottom, 8)
                
                // Description field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("What was this expense for?", text: $description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: description) { oldValue, newValue in
                            viewModel.newExpenseDescription = newValue
                        }
                }
                .padding(.bottom, 8)
                
                // Split type selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Split Type")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
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
            }
            .padding(.horizontal)
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    print("EditExpenseForm: Cancel button tapped")
                    viewModel.clearNavigation()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save Changes") {
                    Task {
                        await viewModel.saveEditedExpense()
                        // Navigation is handled in the viewModel
                    }
                }
                .disabled(amount.isEmpty || !isValidAmount(amount))
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 380)
        .onAppear {
            print("EditExpenseForm.onAppear - expense amount: \(viewModel.newExpenseAmount), description: \(viewModel.newExpenseDescription)")
            
            // Make sure form is initialized from viewModel
            if viewModel.newExpenseAmount > 0 && amount.isEmpty {
                amount = String(format: "%.2f", viewModel.newExpenseAmount)
            }
            if description.isEmpty {
                description = viewModel.newExpenseDescription
            }
            splitType = viewModel.newExpenseSplitType
            
            // Make sure we have an editing expense
            if viewModel.editingExpense == nil {
                print("EditExpenseForm.onAppear - WARNING: editingExpense is nil!")
            } else {
                print("EditExpenseForm.onAppear - editing expense: \(viewModel.editingExpense!.id)")
            }
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