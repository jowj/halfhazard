//
//  CreateTemplateForm.swift
//  halfhazard
//
//  Created by Claude on 2025-07-20.
//

import SwiftUI
import FirebaseFirestore

struct CreateTemplateForm: View {
    @ObservedObject var viewModel: ExpenseTemplateViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddItemSheet = false
    
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var isEditing: Bool {
        viewModel.editingTemplate != nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                #if os(macOS)
                // Don't show title on macOS - it's in the navigation title
                #else
                Text(isEditing ? "Edit Template" : "Create Template")
                    .font(.headline)
                    .padding(.top)
                #endif
                
                VStack(alignment: .leading, spacing: 12) {
                    // Template Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Template Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter template name", text: $viewModel.newTemplateName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Template Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (Optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter description", text: $viewModel.newTemplateDescription)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Template Items Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Template Items")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Add Item") {
                                showingAddItemSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        
                        if viewModel.newTemplateItems.isEmpty {
                            Text("No items added yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(viewModel.newTemplateItems) { item in
                                    TemplateItemRow(
                                        item: item,
                                        currencyFormatter: currencyFormatter,
                                        onEdit: {
                                            viewModel.prepareItemForEditing(item)
                                            showingAddItemSheet = true
                                        },
                                        onDelete: {
                                            viewModel.removeItemFromTemplate(item)
                                        }
                                    )
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                            
                            // Total
                            HStack {
                                Text("Total")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(currencyFormatter.string(from: NSNumber(value: viewModel.newTemplateItems.reduce(0) { $0 + $1.amount })) ?? "$0.00")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 4)
                    }
                }
                #if os(macOS)
                .padding(.horizontal, 24)
                #else
                .padding(.horizontal, 16)
                #endif
                
                Spacer()
                
                // Action Buttons
                HStack {
                    Button("Cancel") {
                        if let appNav = viewModel.appNavigationRef {
                            appNav.navigateBack()
                        } else {
                            dismiss()
                        }
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Button(isEditing ? "Update Template" : "Create Template") {
                        Task {
                            if isEditing {
                                await viewModel.updateTemplate()
                            } else {
                                await viewModel.createTemplate()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.newTemplateName.isEmpty || viewModel.newTemplateItems.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                #if os(macOS)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                #else
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                #endif
            }
        }
        #if os(macOS)
        .frame(width: 500)
        .frame(maxHeight: .infinity)
        #else
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        #endif
        .sheet(isPresented: $showingAddItemSheet) {
            AddTemplateItemSheet(viewModel: viewModel)
        }
        .onAppear {
            // If not editing, reset the form
            if !isEditing {
                viewModel.newTemplateName = ""
                viewModel.newTemplateDescription = ""
                viewModel.newTemplateItems = []
            }
            
            // Clear any previous error messages
            viewModel.errorMessage = nil
        }
    }
}

struct TemplateItemRow: View {
    let item: TemplateItem
    let currencyFormatter: NumberFormatter
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text("\(item.splitType.rawValue.capitalized) split")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let category = item.category, !category.isEmpty {
                    Text("Category: \(category)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(currencyFormatter.string(from: NSNumber(value: item.amount)) ?? "$0.00")
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Button("Edit", action: onEdit)
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                    
                    Button("Delete", action: onDelete)
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Edit Item", action: onEdit)
            Button("Delete Item", role: .destructive, action: onDelete)
        }
    }
}

struct AddTemplateItemSheet: View {
    @ObservedObject var viewModel: ExpenseTemplateViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var amountString = ""
    @FocusState private var isDescriptionFocused: Bool
    
    var isEditing: Bool {
        viewModel.editingItem != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    #if os(macOS)
                    // Don't show title on macOS - it's in the navigation title
                    #else
                    // Don't show title on iOS either - it's already in the navigation bar
                    #endif
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("What was this expense for?", text: $viewModel.newItemDescription)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($isDescriptionFocused)
                        }
                        
                        // Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("0.00", text: $amountString)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .onChange(of: amountString) { _, newValue in
                                    if let amount = Double(newValue) {
                                        viewModel.newItemAmount = amount
                                    } else {
                                        viewModel.newItemAmount = 0
                                    }
                                }
                        }
                        
                        // Split Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Split Type")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("Split Type", selection: $viewModel.newItemSplitType) {
                                Text("Split Equally").tag(SplitType.equal)
                                Text("I Owe All").tag(SplitType.currentUserOwes)
                                Text("I Paid All").tag(SplitType.currentUserOwed)
                                Text("Custom Split").tag(SplitType.custom)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        // Custom Split (simplified for templates)
                        if viewModel.newItemSplitType == .custom {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom Split (Note: Percentages will be applied to group members when template is used)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("For now, this will default to equal split when applied.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .italic()
                            }
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category (Optional)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("e.g., Food, Transport, Utilities", text: $viewModel.newItemCategory)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.top, 4)
                        }
                    }
                    #if os(macOS)
                    .padding(.horizontal, 20)
                    #else
                    .padding(.horizontal, 16)
                    #endif
                    
                    Spacer()
                }
            }
            #if os(macOS)
            .frame(width: 400, height: 500)
            #else
            .frame(maxWidth: .infinity)
            #endif
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Add") {
                        if isEditing {
                            viewModel.updateItemInTemplate()
                        } else {
                            viewModel.addItemToTemplate()
                        }
                        
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                    .disabled(viewModel.newItemDescription.isEmpty || viewModel.newItemAmount <= 0)
                }
            }
        }
        .onAppear {
            // Set up form for editing if needed
            if isEditing {
                amountString = String(format: "%.2f", viewModel.newItemAmount)
            } else {
                // Reset form for new item
                viewModel.newItemAmount = 0
                viewModel.newItemDescription = ""
                viewModel.newItemSplitType = .equal
                viewModel.newItemCustomSplitPercentages = [:]
                viewModel.newItemCategory = ""
                amountString = ""
            }
            
            // Auto-focus description field
            isDescriptionFocused = true
            
            // Clear error messages
            viewModel.errorMessage = nil
        }
        .onDisappear {
            // Clean up editing state
            viewModel.editingItem = nil
        }
    }
}

#Preview {
    let mockViewModel = ExpenseTemplateViewModel(currentUser: nil, useDevMode: true)
    
    return CreateTemplateForm(viewModel: mockViewModel)
}