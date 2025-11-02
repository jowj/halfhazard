//
//  ExpenseTemplateViewModel.swift
//  halfhazard
//
//  Created by Claude on 2025-07-20.
//

import Foundation
import FirebaseFirestore
import SwiftUI

@MainActor
class ExpenseTemplateViewModel: ObservableObject {
    // Services
    private let templateService = ExpenseTemplateService()
    private let expenseService = ExpenseService()
    
    // State
    @Published var templates: [ExpenseTemplate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Form state for creating/editing templates
    @Published var newTemplateName = ""
    @Published var newTemplateDescription = ""
    @Published var newTemplateItems: [TemplateItem] = []
    @Published var editingTemplate: ExpenseTemplate?
    
    // Form state for creating/editing template items
    @Published var newItemAmount: Double = 0
    @Published var newItemDescription = ""
    @Published var newItemSplitType: SplitType = .equal
    @Published var newItemCustomSplitPercentages: [String: Double] = [:]
    @Published var newItemCategory = ""
    @Published var editingItem: TemplateItem?
    
    // Application state
    @Published var selectedTemplateForApplication: ExpenseTemplate?
    @Published var showingTemplateApplicationPreview = false
    
    // Current user context
    var currentUser: User?
    var useDevMode = false
    
    // Navigation reference for iOS
    var appNavigationRef: AppNavigation?
    
    init(currentUser: User?, useDevMode: Bool = false) {
        self.currentUser = currentUser
        self.useDevMode = useDevMode
    }
    
    // MARK: - Context Management
    
    func updateContext(user: User?, devMode: Bool) {
        self.currentUser = user
        self.useDevMode = devMode
    }
    
    // MARK: - Template Management
    
    func loadTemplates() async {
        guard let currentUser = currentUser else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            if useDevMode {
                // Create mock templates for dev mode
                templates = createMockTemplates()
            } else {
                templates = try await templateService.getTemplatesForUser()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load templates: \(error.localizedDescription)"
            print("Error loading templates: \(error)")
        }
    }
    
    func createTemplate() async {
        guard !newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Template name cannot be empty"
            return
        }
        
        guard !newTemplateItems.isEmpty else {
            errorMessage = "Template must contain at least one expense item"
            return
        }
        
        guard let currentUser = currentUser else {
            errorMessage = "User not authenticated"
            return
        }
        
        let template = ExpenseTemplate(
            name: newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: newTemplateDescription.isEmpty ? nil : newTemplateDescription,
            createdBy: currentUser.uid,
            templateItems: newTemplateItems
        )
        
        // Validate the template
        let validationErrors = templateService.validateTemplate(template)
        if !validationErrors.isEmpty {
            errorMessage = validationErrors.first
            return
        }
        
        do {
            if useDevMode {
                // In dev mode, just add to our local array
                templates.insert(template, at: 0)
            } else {
                let createdTemplate = try await templateService.createTemplate(template)
                templates.insert(createdTemplate, at: 0)
            }
            
            // Reset form
            resetTemplateForm()
            errorMessage = nil
            
            // Navigate back
            appNavigationRef?.navigateBack()
        } catch {
            errorMessage = "Failed to create template: \(error.localizedDescription)"
            print("Error creating template: \(error)")
        }
    }
    
    func updateTemplate() async {
        guard let template = editingTemplate else { return }
        
        guard !newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Template name cannot be empty"
            return
        }
        
        guard !newTemplateItems.isEmpty else {
            errorMessage = "Template must contain at least one expense item"
            return
        }
        
        let updatedTemplate = ExpenseTemplate(
            id: template.id,
            name: newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: newTemplateDescription.isEmpty ? nil : newTemplateDescription,
            createdBy: template.createdBy,
            createdAt: template.createdAt,
            templateItems: newTemplateItems,
            isShared: template.isShared
        )
        
        // Validate the template
        let validationErrors = templateService.validateTemplate(updatedTemplate)
        if !validationErrors.isEmpty {
            errorMessage = validationErrors.first
            return
        }
        
        do {
            if useDevMode {
                // In dev mode, update in our local array
                if let index = templates.firstIndex(where: { $0.id == template.id }) {
                    templates[index] = updatedTemplate
                }
            } else {
                let savedTemplate = try await templateService.updateTemplate(updatedTemplate)
                if let index = templates.firstIndex(where: { $0.id == template.id }) {
                    templates[index] = savedTemplate
                }
            }
            
            // Reset form
            resetTemplateForm()
            editingTemplate = nil
            errorMessage = nil
            
            // Navigate back
            appNavigationRef?.navigateBack()
        } catch {
            errorMessage = "Failed to update template: \(error.localizedDescription)"
            print("Error updating template: \(error)")
        }
    }
    
    func deleteTemplate(_ template: ExpenseTemplate) async {
        do {
            if useDevMode {
                // In dev mode, remove from local array
                templates.removeAll { $0.id == template.id }
            } else {
                try await templateService.deleteTemplate(id: template.id)
                templates.removeAll { $0.id == template.id }
            }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to delete template: \(error.localizedDescription)"
            print("Error deleting template: \(error)")
        }
    }
    
    // MARK: - Template Item Management
    
    func addItemToTemplate() {
        guard newItemAmount > 0 else {
            errorMessage = "Item amount must be greater than zero"
            return
        }
        
        guard !newItemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Item description cannot be empty"
            return
        }
        
        let item = TemplateItem(
            amount: newItemAmount,
            description: newItemDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            splitType: newItemSplitType,
            customSplitPercentages: newItemSplitType == .custom && !newItemCustomSplitPercentages.isEmpty ? newItemCustomSplitPercentages : nil,
            category: newItemCategory.isEmpty ? nil : newItemCategory
        )
        
        // Validate custom splits if applicable
        if !item.validateCustomSplits() {
            errorMessage = "Custom split percentages must sum to 100%"
            return
        }
        
        newTemplateItems.append(item)
        resetItemForm()
        errorMessage = nil
    }
    
    func updateItemInTemplate() {
        guard let editingItem = editingItem else { return }
        
        guard newItemAmount > 0 else {
            errorMessage = "Item amount must be greater than zero"
            return
        }
        
        guard !newItemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Item description cannot be empty"
            return
        }
        
        let updatedItem = TemplateItem(
            id: editingItem.id,
            amount: newItemAmount,
            description: newItemDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            splitType: newItemSplitType,
            customSplitPercentages: newItemSplitType == .custom && !newItemCustomSplitPercentages.isEmpty ? newItemCustomSplitPercentages : nil,
            category: newItemCategory.isEmpty ? nil : newItemCategory
        )
        
        // Validate custom splits if applicable
        if !updatedItem.validateCustomSplits() {
            errorMessage = "Custom split percentages must sum to 100%"
            return
        }
        
        if let index = newTemplateItems.firstIndex(where: { $0.id == editingItem.id }) {
            newTemplateItems[index] = updatedItem
        }
        
        resetItemForm()
        self.editingItem = nil
        errorMessage = nil
    }
    
    func removeItemFromTemplate(_ item: TemplateItem) {
        newTemplateItems.removeAll { $0.id == item.id }
    }
    
    func prepareItemForEditing(_ item: TemplateItem) {
        editingItem = item
        newItemAmount = item.amount
        newItemDescription = item.description
        newItemSplitType = item.splitType
        newItemCustomSplitPercentages = item.customSplitPercentages ?? [:]
        newItemCategory = item.category ?? ""
    }
    
    // MARK: - Template Application
    
    func applyTemplateToGroup(_ template: ExpenseTemplate, groupId: String) async -> [Expense]? {
        guard let currentUser = currentUser else {
            errorMessage = "User not authenticated"
            return nil
        }
        
        do {
            if useDevMode {
                // In dev mode, create mock expenses
                return createMockExpensesFromTemplate(template, groupId: groupId, userId: currentUser.uid)
            } else {
                let createdExpenses = try await templateService.applyTemplateToGroup(
                    templateId: template.id,
                    groupId: groupId,
                    expenseService: expenseService
                )
                errorMessage = nil
                return createdExpenses
            }
        } catch {
            errorMessage = "Failed to apply template: \(error.localizedDescription)"
            print("Error applying template: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    func prepareTemplateForEditing(_ template: ExpenseTemplate) {
        editingTemplate = template
        newTemplateName = template.name
        newTemplateDescription = template.description ?? ""
        newTemplateItems = template.templateItems
    }
    
    private func resetTemplateForm() {
        newTemplateName = ""
        newTemplateDescription = ""
        newTemplateItems = []
        resetItemForm()
    }
    
    private func resetItemForm() {
        newItemAmount = 0
        newItemDescription = ""
        newItemSplitType = .equal
        newItemCustomSplitPercentages = [:]
        newItemCategory = ""
    }
    
    // MARK: - Dev Mode Mock Data
    
    private func createMockTemplates() -> [ExpenseTemplate] {
        return [
            ExpenseTemplate(
                name: "Weekly Groceries",
                description: "Standard weekly grocery run",
                createdBy: currentUser?.uid ?? "dev-user",
                templateItems: [
                    TemplateItem(amount: 120.0, description: "Grocery Store", splitType: .equal),
                    TemplateItem(amount: 15.0, description: "Coffee Beans", splitType: .currentUserOwes),
                    TemplateItem(amount: 8.0, description: "Snacks", splitType: .equal)
                ]
            ),
            ExpenseTemplate(
                name: "Monthly Utilities",
                description: "Standard monthly bills",
                createdBy: currentUser?.uid ?? "dev-user",
                templateItems: [
                    TemplateItem(amount: 80.0, description: "Electricity", splitType: .equal),
                    TemplateItem(amount: 45.0, description: "Internet", splitType: .equal),
                    TemplateItem(amount: 25.0, description: "Water", splitType: .equal)
                ]
            ),
            ExpenseTemplate(
                name: "Night Out",
                description: "Dinner and drinks",
                createdBy: currentUser?.uid ?? "dev-user",
                templateItems: [
                    TemplateItem(amount: 85.0, description: "Dinner", splitType: .equal),
                    TemplateItem(amount: 45.0, description: "Drinks", splitType: .equal),
                    TemplateItem(amount: 12.0, description: "Uber", splitType: .equal)
                ]
            )
        ]
    }
    
    private func createMockExpensesFromTemplate(_ template: ExpenseTemplate, groupId: String, userId: String) -> [Expense] {
        // Mock group members for dev mode
        let mockGroupMembers = [userId, "dev-user-2", "dev-user-3"]
        
        return template.templateItems.map { item in
            item.createExpense(forGroup: groupId, createdBy: userId, groupMembers: mockGroupMembers)
        }
    }
}