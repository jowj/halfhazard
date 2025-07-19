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
        VStack(spacing: 16) {
            Text("Add Expense")
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
                        // macOS doesn't support keyboardType
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
                        Text("Split Equally").tag(SplitType.equal)
                        Text("I Owe All").tag(SplitType.currentUserOwes)
                        Text("I Paid All").tag(SplitType.currentUserOwed)
                        Text("Custom Split").tag(SplitType.custom)
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
                    if let appNav = viewModel.appNavigationRef {
                        appNav.navigateBack()
                    } else {
                        dismiss()
                    }
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create Expense") {
                    Task {
                        await viewModel.createExpense()
                        // Navigation is handled in the viewModel
                    }
                }
                .disabled(amount.isEmpty || !isValidAmount(amount))
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
        .frame(width: 400, height: 380)
        .onAppear {
            print("CreateExpenseForm.onAppear - Form appeared")
            
            // Reset viewModel state for new expense
            viewModel.newExpenseAmount = 0
            viewModel.newExpenseDescription = ""
            viewModel.newExpenseSplitType = .equal
            
            // Make sure we have a current group ID
            if let groupId = viewModel.currentGroupId {
                print("CreateExpenseForm.onAppear - Current group ID: \(groupId)")
            } else {
                print("CreateExpenseForm.onAppear - WARNING: No current group ID!")
            }
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