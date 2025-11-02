//
//  CustomSplitView.swift
//  halfhazard
//
//  Created by Claude on 2025-01-19.
//

import SwiftUI

struct CustomSplitView: View {
    @ObservedObject var viewModel: ExpenseViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Split")
                    .font(.headline)
                Spacer()
                Button("Equal Split") {
                    viewModel.initializeEqualCustomSplits()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            
            if let group = viewModel.currentGroup {
                ForEach(group.memberIds, id: \.self) { memberId in
                    CustomSplitRowView(
                        memberId: memberId,
                        memberName: getMemberName(memberId),
                        percentage: viewModel.newCustomSplitPercentages[memberId] ?? 0,
                        amount: calculateAmount(for: memberId),
                        onPercentageChange: { newPercentage in
                            viewModel.updateCustomSplitPercentage(for: memberId, percentage: newPercentage)
                        }
                    )
                    .id(memberId) // Use stable ID
                }
                
                // Summary row
                HStack {
                    Text("Total:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(String(format: "%.1f", viewModel.getTotalCustomSplitPercentage()))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.isCustomSplitValid() ? .primary : .red)
                    Text("$\(String(format: "%.2f", viewModel.newExpenseAmount))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                if !viewModel.isCustomSplitValid() {
                    let remaining = viewModel.getRemainingPercentage()
                    Text("⚠️ Percentages must sum to 100%. \(remaining > 0 ? "Missing" : "Over by") \(String(format: "%.1f", abs(remaining)))%")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
        }
        .onAppear {
            // Initialize with equal splits if no custom splits are set
            if viewModel.newCustomSplitPercentages.isEmpty {
                viewModel.initializeEqualCustomSplits()
            }
        }
    }
    
    private func getMemberName(_ memberId: String) -> String {
        // For now, just use the member ID
        // In a full implementation, you'd fetch the member name from user data
        if memberId == viewModel.currentUser?.uid {
            return "You"
        }
        return "User \(memberId.prefix(8))"
    }
    
    private func calculateAmount(for memberId: String) -> Double {
        let percentage = viewModel.newCustomSplitPercentages[memberId] ?? 0
        return viewModel.newExpenseAmount * (percentage / 100.0)
    }
}

struct CustomSplitRowView: View {
    let memberId: String
    let memberName: String
    let percentage: Double
    let amount: Double
    let onPercentageChange: (Double) -> Void

    @State private var percentageText: String = ""
    @State private var isUpdating: Bool = false
    @FocusState private var isPercentageFocused: Bool
    
    var body: some View {
        let _ = print("CustomSplitRowView body evaluated for \(memberId) with percentage \(percentage)")
        HStack {
            Text(memberName)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                TextField("0", text: $percentageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    .focused($isPercentageFocused)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .onChange(of: percentageText) { oldValue, newValue in
                        // Prevent update loops
                        guard !isUpdating else { return }
                        // Only update if the text actually changed and we can parse it
                        guard oldValue != newValue, let value = Double(newValue) else { return }
                        // Only update if the value is different from current percentage
                        guard abs(value - percentage) > 0.01 else { return }
                        isUpdating = true
                        onPercentageChange(value)
                        // Reset flag after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isUpdating = false
                        }
                    }
                    #if os(iOS)
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                        // Update text field when keyboard is dismissed
                        if isPercentageFocused {
                            percentageText = String(format: "%.1f", percentage)
                        }
                    }
                    #endif
                
                Text("%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("$\(String(format: "%.2f", amount))")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .onAppear {
            percentageText = String(format: "%.1f", percentage)
        }
        .onChange(of: percentage) { oldValue, newValue in
            // Only update text if not currently editing and value actually changed
            if !isPercentageFocused && abs(oldValue - newValue) > 0.01 {
                percentageText = String(format: "%.1f", newValue)
            }
        }
    }
}

#Preview {
    CustomSplitView(viewModel: ExpenseViewModel(currentUser: nil))
}