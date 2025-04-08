//
//  ExpenseRow.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import SwiftUI
import FirebaseFirestore

struct ExpenseRow: View {
    let expense: Expense
    let group: Group
    @State private var creatorName: String = "Unknown"
    @StateObject private var userService = UserService()
    
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            // Main content
            VStack(alignment: .leading, spacing: 4) {
                // Title and date
                Text(expense.description ?? "Expense")
                    .font(.headline)
                
                // Creator and date
                Text("Added by \(creatorName) • \(dateFormatter.string(from: expense.createdAt.dateValue()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    // Split type badge
                    Label(splitTypeLabel(for: expense.splitType), systemImage: "person.3")
                        .font(.caption)
                        .padding(4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    
                    // Settled badge (if settled)
                    if expense.settled {
                        Label("Settled", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            // Right side - amount and chevron
            VStack(alignment: .trailing, spacing: 4) {
                // Amount
                Text(currencyFormatter.string(from: NSNumber(value: expense.amount)) ?? "$0.00")
                    .font(.title3.bold())
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
        .task {
            // Load creator name
            do {
                let creator = try await userService.getUser(uid: expense.createdBy)
                creatorName = creator.displayName ?? creator.email
            } catch {
                print("Error loading creator: \(error)")
            }
        }
    }
    
    private func splitTypeLabel(for type: SplitType) -> String {
        switch type {
        case .equal:
            return "Split Equally"
        case .currentUserOwed:
            return "You Paid"
        case .currentUserOwes:
            return "You Owe"
        case .custom:
            return "Custom Split"
        }
    }
}

#Preview {
    ExpenseRow(
        expense: Expense(
            id: "preview-expense",
            amount: 100.0,
            description: "Dinner",
            groupId: "group-id",
            createdBy: "user-id",
            createdAt: Timestamp(),
            splitType: .equal,
            splits: ["user-id": 100.0],
            settled: false,
            settledAt: nil
        ),
        group: Group(
            id: "group-id",
            name: "Friends",
            memberIds: ["user-id"],
            createdBy: "user-id",
            createdAt: Timestamp(),
            settings: Settings(name: ""),
            settled: false,
            settledAt: nil
        )
    )
    .padding()
}