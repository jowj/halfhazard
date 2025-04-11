//
//  ExpenseDetailView.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import SwiftUI
import FirebaseFirestore

struct ExpenseDetailView: View {
    let expense: Expense
    let group: Group
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userService = UserService()
    
    // For navigation support
    var appNavigation: AppNavigation

    init(expense: Expense, group: Group, expenseViewModel: ExpenseViewModel? = nil, appNavigationRef: AppNavigation) {
        self.expense = expense
        self.group = group
        self.appNavigation = appNavigationRef
        _userService = StateObject(wrappedValue: {
            let service = UserService()
            service.expenseViewModel = expenseViewModel
            return service
        }())
    }
    
    @State private var memberNames: [String: String] = [:]
    @State private var memberImages: [String: String] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    
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
    
    private let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    var body: some View {
        List {
            // Expense header section
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(expense.description ?? "Expense")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            if let creatorName = memberNames[expense.createdBy] {
                                Text("Added by \(creatorName)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(dateFormatter.string(from: expense.createdAt.dateValue()))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(currencyFormatter.string(from: NSNumber(value: expense.amount)) ?? "$0.00")
                            .font(.title.bold())
                    }
                    .padding(.vertical, 4)
                    
                    // Split type badge
                    HStack {
                        Label(splitTypeLabel(for: expense.splitType), systemImage: splitTypeIcon(for: expense.splitType))
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        
                        Spacer()
                    }
                }
            }
            
            // Splits section with visual indicator
            Section(header: Text("Split Details")) {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    // Summary chart
                    if !expense.splits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Split Distribution")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            splitBarChart
                        }
                        .padding(.vertical, 12)
                    }
                    
                    // Individual splits
                    ForEach(group.memberIds, id: \.self) { memberId in
                        if let split = expense.splits[memberId], let name = memberNames[memberId] {
                            HStack {
                                // Member initials or icon
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    
                                    Text(getInitials(for: name))
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                
                                // Member name
                                VStack(alignment: .leading) {
                                    Text(name)
                                        .font(.body)
                                    
                                    // Show percentage in addition to amount
                                    if expense.splitType == .currentUserOwed || expense.splitType == .currentUserOwes || expense.splitType == .custom {
                                        let percentage = split / expense.amount
                                        Text(percentFormatter.string(from: NSNumber(value: percentage)) ?? "0%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Split amount
                                Text(currencyFormatter.string(from: NSNumber(value: split)) ?? "$0.00")
                                    .font(.body.bold())
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            
            // Payment status section
            Section(header: Text("Payment Status")) {
                VStack(alignment: .leading, spacing: 12) {
                    // Status indicator
                    HStack {
                        Image(systemName: expense.settled ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(expense.settled ? .green : .secondary)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text(expense.settled ? "Settled" : "Unsettled")
                                .font(.headline)
                                .foregroundColor(expense.settled ? .green : .primary)
                            
                            if expense.settled, let settledAt = expense.settledAt {
                                Text("Settled on \(dateFormatter.string(from: settledAt.dateValue()))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    
                    // Settle/unsettle button
                    if let expenseVM = userService.expenseViewModel {
                        if expense.settled {
                            Button {
                                Task {
                                    await expenseVM.unsettleExpense(expense: expense)
                                    // Navigate back
                                    appNavigation.navigateBack()
                                }
                            } label: {
                                Label("Mark as Unsettled", systemImage: "arrow.counterclockwise.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        } else {
                            Button {
                                Task {
                                    await expenseVM.settleExpense(expense: expense)
                                    // Navigate back
                                    appNavigation.navigateBack()
                                }
                            } label: {
                                Label("Mark as Settled", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Expense Details")
        .toolbar {
            // Action button for expense actions - keep only this, remove custom back button
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // Edit button - only available to expense creator or group admin
                    Button {
                        // Prepare the expense for editing and show edit form
                        if let expenseVM = userService.expenseViewModel {
                            expenseVM.prepareExpenseForEditing(expense)
                            appNavigation.showEditExpenseForm(expense: expense)
                        }
                    } label: {
                        Label("Edit Expense", systemImage: "pencil")
                    }
                    // Only enable for creator or group admin
                    .disabled(!(expense.createdBy == userService.auth.currentUser?.uid || 
                              group.createdBy == userService.auth.currentUser?.uid))
                    
                    Divider()
                    
                    // Export option - available to all group members
                    Button {
                        exportExpenseToCSV()
                    } label: {
                        Label("Export as CSV", systemImage: "arrow.down.doc")
                    }
                    
                    Divider()
                    
                    // Delete button - only enabled for expense creator or group admin
                    Button(role: .destructive) {
                        // Delete the expense and close the detail view
                        if let expenseVM = userService.expenseViewModel {
                            Task {
                                await expenseVM.deleteExpense(expense: expense)
                                appNavigation.navigateBack()
                            }
                        }
                    } label: {
                        Label("Delete Expense", systemImage: "trash")
                    }
                    // Only enable for creator or group admin
                    .disabled(!(expense.createdBy == userService.auth.currentUser?.uid || 
                               group.createdBy == userService.auth.currentUser?.uid))
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert(
            "Error",
            isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            actions: {
                Button("OK") {
                    errorMessage = nil
                }
            },
            message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        )
        .task {
            await loadMemberNames()
        }
        .onAppear {
            // Set the expenseViewModel appNavigationRef if needed
            if let expenseVM = userService.expenseViewModel, expenseVM.appNavigationRef == nil {
                expenseVM.appNavigationRef = appNavigation
            }
        }
    }
    
    // Visual bar chart showing split distribution
    private var splitBarChart: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(getSortedSplits(), id: \.key) { (memberId, info) in
                    let percentage = info.amount / expense.amount
                    let width = geometry.size.width * CGFloat(percentage)
                    
                    Rectangle()
                        .fill(randomColor(for: memberId))
                        .frame(width: width)
                        .overlay {
                            if width > 60 {
                                Text(percentFormatter.string(from: NSNumber(value: percentage)) ?? "")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                            }
                        }
                }
            }
            .frame(height: 24)
            .cornerRadius(6)
            
            // Legend
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                    .frame(height: 32)
                
                ForEach(getSortedSplits(), id: \.key) { (memberId, info) in
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(randomColor(for: memberId))
                            .frame(width: 12, height: 12)
                            .cornerRadius(2)
                        
                        Text(info.name)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(percentFormatter.string(from: NSNumber(value: info.amount / expense.amount)) ?? "")
                            .font(.caption)
                    }
                }
            }
            .padding(.top, 8)
        }
        .frame(height: 130)
        .padding(.horizontal, 4)
    }
    
    private func getInitials(for name: String) -> String {
        let components = name.components(separatedBy: " ")
        if components.count > 1, 
           let first = components.first?.first,
           let last = components.last?.first {
            return "\(first)\(last)"
        } else if let first = name.first {
            return String(first)
        }
        return "?"
    }
    
    // Get sorted splits with names for chart
    private func getSortedSplits() -> [(key: String, value: (amount: Double, name: String))] {
        let splitsWithNames = expense.splits.compactMap { (memberId, amount) -> (key: String, value: (amount: Double, name: String))? in
            if let name = memberNames[memberId] {
                return (key: memberId, value: (amount: amount, name: name))
            }
            return nil
        }
        
        return splitsWithNames.sorted { $0.value.amount > $1.value.amount }
    }
    
    // Generate consistent colors based on member ID
    private func randomColor(for memberId: String) -> Color {
        let colors: [Color] = [
            .blue, .green, .orange, .red, .purple, .teal, .pink, .yellow
        ]
        
        // Use a hash of the memberId to get a consistent color
        var hash = 0
        for char in memberId {
            hash = ((hash << 5) &- hash) &+ Int(char.asciiValue ?? 0)
        }
        
        let index = abs(hash) % colors.count
        return colors[index]
    }
    
    private func loadMemberNames() async {
        isLoading = true
        defer { isLoading = false }
        
        // Create an empty dictionary to store member names
        var names: [String: String] = [:]
        
        // Fetch names for all group members
        for memberId in group.memberIds {
            do {
                let user = try await userService.getUser(uid: memberId)
                names[memberId] = user.displayName ?? user.email
            } catch {
                print("Error loading member \(memberId): \(error)")
                names[memberId] = "Unknown User"
            }
        }
        
        // Update the state
        self.memberNames = names
    }
    
    private func splitTypeIcon(for type: SplitType) -> String {
        switch type {
        case .equal:
            return "equal.square.fill"
        case .currentUserOwed:
            return "arrow.left.square.fill"
        case .currentUserOwes:
            return "arrow.right.square.fill"
        case .custom:
            return "slider.horizontal.3"
        }
    }
    
    private func splitTypeLabel(for type: SplitType) -> String {
        switch type {
        case .equal:
            return "Split Equally"
        case .currentUserOwed:
            return "You Paid (Others Owe You)"
        case .currentUserOwes:
            return "You Owe (Someone Else Paid)"
        case .custom:
            return "Custom Split"
        }
    }
    
    // Export expense to CSV
    private func exportExpenseToCSV() {
        // Create a descriptive file name based on expense details
        let description = expense.description?.replacingOccurrences(of: " ", with: "_") ?? "Expense"
        let fileName = "\(description)_\(dateFormatter.string(from: expense.createdAt.dateValue()).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: ":", with: "."))"
        
        // Export the expense as CSV
        let csvContent = expense.toCSV(memberNames: memberNames)
        
        // Share the CSV file
        Task { @MainActor in
            let success = FileExportManager.shareCSV(csvContent, fileName: fileName)
            if !success {
                errorMessage = "Failed to export expense to CSV"
            }
        }
    }
}

// Preview provider (uncomment and modify for actual use)
/*
#Preview {
    let mockTimestamp = Timestamp(date: Date())
    let mockExpense = Expense(
        id: "mock-expense-id",
        amount: 120.50,
        description: "Team Dinner",
        groupId: "mock-group-id",
        createdBy: "user1",
        createdAt: mockTimestamp,
        splitType: .equal,
        splits: [
            "user1": 40.17,
            "user2": 40.17,
            "user3": 40.16
        ]
    )
    
    let mockGroup = Group(
        id: "mock-group-id",
        name: "Friends",
        memberIds: ["user1", "user2", "user3"],
        createdBy: "user1",
        createdAt: mockTimestamp,
        settings: Settings(name: "Trip to Paris")
    )
    
    return ExpenseDetailView(expense: mockExpense, group: mockGroup)
}
*/