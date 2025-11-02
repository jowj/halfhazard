//
//  ExpenseTemplateService.swift
//  halfhazard
//
//  Created by Claude on 2025-07-20.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class ExpenseTemplateService {
    private let db = Firestore.firestore()
    
    // MARK: - Template Management
    
    /// Create a new expense template
    func createTemplate(_ template: ExpenseTemplate) async throws -> ExpenseTemplate {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ExpenseTemplateService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Ensure the template is created by the current user
        guard template.createdBy == currentUser.uid else {
            throw NSError(domain: "ExpenseTemplateService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot create template for another user"])
        }
        
        // Create document reference
        let templateRef = db.collection("users").document(currentUser.uid)
                           .collection("expenseTemplates").document(template.id)
        
        // Save to Firestore
        try templateRef.setData(from: template)
        
        return template
    }
    
    /// Get all templates for the current user
    func getTemplatesForUser() async throws -> [ExpenseTemplate] {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ExpenseTemplateService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let templatesRef = db.collection("users").document(currentUser.uid)
                            .collection("expenseTemplates")
        
        let snapshot = try await templatesRef.order(by: "createdAt", descending: true).getDocuments()
        
        var templates: [ExpenseTemplate] = []
        for document in snapshot.documents {
            do {
                let template = try document.data(as: ExpenseTemplate.self)
                templates.append(template)
            } catch {
                print("Error decoding template \(document.documentID): \(error)")
                // Continue processing other templates
            }
        }
        
        return templates
    }
    
    /// Get a specific template by ID
    func getTemplate(id: String) async throws -> ExpenseTemplate {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ExpenseTemplateService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let templateRef = db.collection("users").document(currentUser.uid)
                           .collection("expenseTemplates").document(id)
        
        let document = try await templateRef.getDocument()
        
        guard document.exists else {
            throw NSError(domain: "ExpenseTemplateService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Template not found"])
        }
        
        return try document.data(as: ExpenseTemplate.self)
    }
    
    /// Update an existing template
    func updateTemplate(_ template: ExpenseTemplate) async throws -> ExpenseTemplate {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ExpenseTemplateService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Ensure the template belongs to the current user
        guard template.createdBy == currentUser.uid else {
            throw NSError(domain: "ExpenseTemplateService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot update template belonging to another user"])
        }
        
        let templateRef = db.collection("users").document(currentUser.uid)
                           .collection("expenseTemplates").document(template.id)
        
        // Update in Firestore
        try templateRef.setData(from: template)
        
        return template
    }
    
    /// Delete a template
    func deleteTemplate(id: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ExpenseTemplateService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // First verify the template belongs to the current user
        let template = try await getTemplate(id: id)
        guard template.createdBy == currentUser.uid else {
            throw NSError(domain: "ExpenseTemplateService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot delete template belonging to another user"])
        }
        
        let templateRef = db.collection("users").document(currentUser.uid)
                           .collection("expenseTemplates").document(id)
        
        try await templateRef.delete()
    }
    
    // MARK: - Template Application
    
    /// Apply a template to a group, creating actual expenses
    func applyTemplateToGroup(templateId: String, 
                             groupId: String, 
                             expenseService: ExpenseService) async throws -> [Expense] {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ExpenseTemplateService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the template
        let template = try await getTemplate(id: templateId)
        
        // Get group information to determine members
        let groupService = GroupService()
        let group = try await groupService.getGroupInfo(groupID: groupId)
        
        // Verify user is a member of the group
        guard group.memberIds.contains(currentUser.uid) else {
            throw NSError(domain: "ExpenseTemplateService", code: 403, userInfo: [NSLocalizedDescriptionKey: "User is not a member of the target group"])
        }
        
        var createdExpenses: [Expense] = []
        
        // Create expenses from template items
        for templateItem in template.templateItems {
            let expense = templateItem.createExpense(
                forGroup: groupId,
                createdBy: currentUser.uid,
                groupMembers: group.memberIds
            )
            
            // Create the expense using the existing expense service
            let createdExpense = try await expenseService.createExpense(
                amount: expense.amount,
                description: expense.description,
                groupId: expense.groupId,
                splitType: expense.splitType,
                splits: expense.splits,
                customSplitPercentages: expense.customSplitPercentages
            )
            
            createdExpenses.append(createdExpense)
        }
        
        return createdExpenses
    }
    
    // MARK: - Validation
    
    /// Validate that a template is properly formed
    func validateTemplate(_ template: ExpenseTemplate) -> [String] {
        var errors: [String] = []
        
        // Check basic properties
        if template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Template name cannot be empty")
        }
        
        if template.templateItems.isEmpty {
            errors.append("Template must contain at least one expense item")
        }
        
        // Validate each template item
        for (index, item) in template.templateItems.enumerated() {
            if item.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("Item \(index + 1): Description cannot be empty")
            }
            
            if item.amount <= 0 {
                errors.append("Item \(index + 1): Amount must be greater than zero")
            }
            
            if !item.validateCustomSplits() {
                errors.append("Item \(index + 1): Custom split percentages must sum to 100%")
            }
        }
        
        return errors
    }
}