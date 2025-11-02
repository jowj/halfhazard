//
//  ExpenseTemplateListView.swift
//  halfhazard
//
//  Created by Claude on 2025-07-20.
//

import SwiftUI
import FirebaseFirestore

struct ExpenseTemplateListView: View {
    @ObservedObject var viewModel: ExpenseTemplateViewModel
    var appNavigationRef: AppNavigation
    var currentGroup: Group? = nil
    var expenseViewModel: ExpenseViewModel? = nil
    @State private var showingDeleteConfirmation = false
    @State private var templateToDelete: ExpenseTemplate?
    
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.templates.isEmpty {
                ContentUnavailableView(
                    "No Templates",
                    systemImage: "doc.text",
                    description: Text("Create your first expense template to get started")
                )
            } else {
                List {
                    ForEach(viewModel.templates) { template in
                        TemplateRowView(
                            template: template,
                            currencyFormatter: currencyFormatter,
                            onEdit: {
                                viewModel.prepareTemplateForEditing(template)
                                appNavigationRef.showEditTemplateForm()
                            },
                            onDelete: {
                                templateToDelete = template
                                showingDeleteConfirmation = true
                            },
                            onApply: {
                                viewModel.selectedTemplateForApplication = template
                                viewModel.showingTemplateApplicationPreview = true
                            }
                        )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Expense Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    appNavigationRef.showCreateTemplateForm()
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Delete Template", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                templateToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let template = templateToDelete {
                    Task {
                        await viewModel.deleteTemplate(template)
                    }
                }
                templateToDelete = nil
            }
        } message: {
            if let template = templateToDelete {
                Text("Are you sure you want to delete \"\(template.name)\"? This action cannot be undone.")
            }
        }
        .sheet(isPresented: $viewModel.showingTemplateApplicationPreview) {
            if let template = viewModel.selectedTemplateForApplication {
                TemplateApplicationPreviewSheet(
                    template: template,
                    viewModel: viewModel,
                    appNavigation: appNavigationRef,
                    currentGroup: currentGroup,
                    expenseViewModel: expenseViewModel
                )
            }
        }
        .task {
            await viewModel.loadTemplates()
        }
        .onAppear {
            viewModel.appNavigationRef = appNavigationRef
        }
    }
}

struct TemplateRowView: View {
    let template: ExpenseTemplate
    let currencyFormatter: NumberFormatter
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = template.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currencyFormatter.string(from: NSNumber(value: template.totalAmount)) ?? "$0.00")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(template.templateItems.count) item\(template.templateItems.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Preview of template items
            VStack(alignment: .leading, spacing: 2) {
                let previewItems = template.getPreview(limit: 3)
                ForEach(previewItems) { item in
                    HStack {
                        Text("• \(item.description)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(currencyFormatter.string(from: NSNumber(value: item.amount)) ?? "$0.00")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if template.templateItems.count > 3 {
                    Text("... and \(template.templateItems.count - 3) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
            
            HStack(spacing: 12) {
                Button("Apply", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                
                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                
                Spacer()
                
                Text(formatDate(template.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Apply Template", action: onApply)
            Button("Edit Template", action: onEdit)
            Divider()
            Button("Delete Template", role: .destructive, action: onDelete)
        }
    }
    
    private func formatDate(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: timestamp.dateValue())
    }
}

struct TemplateApplicationPreviewSheet: View {
    let template: ExpenseTemplate
    @ObservedObject var viewModel: ExpenseTemplateViewModel
    let appNavigation: AppNavigation
    let currentGroup: Group?
    let expenseViewModel: ExpenseViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var isApplying = false
    
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Apply Template")
                    .font(.headline)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Template: \(template.name)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let description = template.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Total: \(currencyFormatter.string(from: NSNumber(value: template.totalAmount)) ?? "$0.00")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                if let group = currentGroup {
                    Text("This will create \(template.templateItems.count) expense\(template.templateItems.count == 1 ? "" : "s") in \"\(group.name)\":")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("No group selected. Please select a group first.")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                
                List(template.templateItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description)
                                .font(.body)
                            
                            Text("\(item.splitType.rawValue.capitalized) split")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(currencyFormatter.string(from: NSNumber(value: item.amount)) ?? "$0.00")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 2)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(isApplying ? "Applying..." : "Apply Template") {
                        Task {
                            guard let group = currentGroup else {
                                viewModel.errorMessage = "No group selected"
                                return
                            }
                            
                            isApplying = true
                            let success = await viewModel.applyTemplateToGroup(template, groupId: group.id)
                            isApplying = false
                            
                            if success != nil {
                                // Template applied successfully - refresh expense list and dismiss
                                if let expenseViewModel = expenseViewModel {
                                    await expenseViewModel.loadExpenses(forGroupId: group.id)
                                }
                                dismiss()
                                appNavigation.navigateBack()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentGroup == nil || isApplying)
                }
                .padding()
            }
            .padding()
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}

#Preview {
    let mockViewModel = ExpenseTemplateViewModel(currentUser: nil, useDevMode: true)
    let mockAppNav = AppNavigation()
    
    return ExpenseTemplateListView(
        viewModel: mockViewModel,
        appNavigationRef: mockAppNav,
        currentGroup: nil
    )
}