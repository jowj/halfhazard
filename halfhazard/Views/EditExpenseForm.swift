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
    @FocusState private var isDescriptionFocused: Bool
    
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
                // Description field (moved first)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("What was this expense for?", text: $description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isDescriptionFocused)
                        .onChange(of: description) { oldValue, newValue in
                            viewModel.newExpenseDescription = newValue
                        }
                }
                .padding(.bottom, 8)
                
                // Amount field (moved second)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("0.00", text: $amount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .onChange(of: amount) { oldValue, newValue in
                            // Update view model
                            if let amountDouble = Double(newValue) {
                                viewModel.newExpenseAmount = amountDouble
                            } else {
                                viewModel.newExpenseAmount = 0
                            }
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
                        
                        // Initialize custom splits when switching to custom
                        if newValue == .custom && viewModel.newCustomSplitPercentages.isEmpty {
                            viewModel.initializeEqualCustomSplits()
                        }
                    }
                }
                
                // Custom split configuration
                if splitType == .custom {
                    CustomSplitView(viewModel: viewModel)
                        .padding(.top, 8)
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
                
                Button("Save Changes") {
                    Task {
                        await viewModel.saveEditedExpense()
                        // Navigation is handled in the viewModel
                    }
                }
                .disabled(amount.isEmpty || !isValidAmount(amount) || (splitType == .custom && !viewModel.isCustomSplitValid()))
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
        .frame(width: 400, height: splitType == .custom ? 600 : 380)
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
            
            // Auto-focus the description field
            isDescriptionFocused = true
            
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