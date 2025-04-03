//
//  ImportExpensePreview.swift
//  halfhazard
//
//  Created by Claude on 2025-04-03.
//

import SwiftUI
import FirebaseFirestore

struct ImportExpensePreview: View {
    @ObservedObject var viewModel: ExpenseViewModel
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("Preview Import from \(viewModel.importState.fileName)")
                            .font(.headline)
                        Text(viewModel.importState.summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if viewModel.importState.hasErrors {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Warnings:")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        ForEach(viewModel.importState.errorMessages.prefix(3), id: \.self) { error in
                            Text("• \(error)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if viewModel.importState.errorMessages.count > 3 {
                            Text("• ...and \(viewModel.importState.errorMessages.count - 3) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            
            Divider()
            
            // Preview list
            List {
                Section(header: Text("Sample of \(viewModel.importState.previewCount) out of \(viewModel.importState.parsedExpenses.count) expenses")) {
                    ForEach(viewModel.importState.parsedExpenses.prefix(viewModel.importState.previewCount)) { expense in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expense.description ?? "Expense")
                                    .fontWeight(.medium)
                                
                                Text(dateFormatter.string(from: expense.createdAt.dateValue()))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Amount and status
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(currencyFormatter.string(from: NSNumber(value: expense.amount)) ?? "$0.00")
                                    .fontWeight(.semibold)
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(expense.settled ? Color.green : Color.gray)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(expense.settled ? "Settled" : "Unsettled")
                                        .font(.caption)
                                        .foregroundColor(expense.settled ? .green : .secondary)
                                        .fontWeight(expense.settled ? .medium : .regular)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.inset)
            
            Divider()
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    viewModel.cancelImportExpenses()
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("Import \(viewModel.importState.parsedExpenses.count) Expense(s)") {
                    Task {
                        await viewModel.confirmImportExpenses()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
        }
        .frame(minWidth: 500, idealWidth: 550, maxWidth: 600, minHeight: 400, idealHeight: 450, maxHeight: 500)
    }
}

// MARK: - Preview
#Preview {
    ImportExpensePreview(
        viewModel: {
            let vm = ExpenseViewModel(currentUser: nil, useDevMode: true)
            vm.importState.isPreviewing = true
            vm.importState.isImporting = true
            vm.importState.fileName = "expenses.csv"
            vm.importState.parsedExpenses = [
                Expense(
                    id: "1",
                    amount: 25.99,
                    description: "Team Lunch",
                    groupId: "g1",
                    createdBy: "u1",
                    createdAt: Timestamp(date: Date()),
                    splits: ["u1": 8.66, "u2": 8.66, "u3": 8.67],
                    settled: false
                ),
                Expense(
                    id: "2",
                    amount: 50.0,
                    description: "Office Supplies",
                    groupId: "g1",
                    createdBy: "u1",
                    createdAt: Timestamp(date: Date().addingTimeInterval(-86400)),
                    splits: ["u1": 16.67, "u2": 16.67, "u3": 16.66],
                    settled: true
                )
            ]
            return vm
        }()
    )
}