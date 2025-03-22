//
//  ExpenseService.swift
//  halfhazard
//
//  Created by Claude on 2025-03-21.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

import Combine

class ExpenseService: ObservableObject {
    // setup firebase
    let db = Firestore.firestore()
    
    // Create a new expense
    func createExpense(amount: Double, description: String?, groupId: String, splitType: SplitType, splits: [String: Double]) async throws -> Expense {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ExpenseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Create a new document reference with auto-generated ID
        let expenseRef = db.collection("expenses").document()
        
        // Create a new expense
        let expense = Expense(
            id: expenseRef.documentID,
            amount: amount,
            description: description,
            groupId: groupId,
            createdBy: currentUser.uid,
            createdAt: Timestamp(),
            splitType: splitType,
            splits: splits
        )
        
        // Save expense to Firestore
        try expenseRef.setData(from: expense)
        
        return expense
    }
    
    // Get all expenses for a group, ensuring the current user is a member of that group
    func getExpensesForGroup(groupId: String) async throws -> [Expense] {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ExpenseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // First, verify the user is a member of this group
        let groupRef = db.collection("groups").document(groupId)
        do {
            let group = try await groupRef.getDocument(as: Group.self)
            
            // Check if the current user is a member of this group
            guard group.memberIds.contains(currentUser.uid) else {
                throw NSError(domain: "ExpenseService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You are not a member of this group"])
            }
            
            // User is authorized, proceed with getting expenses
            let querySnapshot = try await db.collection("expenses")
                .whereField("groupId", isEqualTo: groupId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            var expenses: [Expense] = []
            for document in querySnapshot.documents {
                let expense = try document.data(as: Expense.self)
                expenses.append(expense)
            }
            
            return expenses
        } catch let error as NSError {
            // Check if it's a missing index error
            if error.domain == "FIRFirestoreErrorDomain" && 
               error.code == 9 && 
               error.localizedDescription.contains("The query requires an index") {
                
                // Extract the index creation URL from the error message
                let errorMessage = error.localizedDescription
                var indexURL = ""
                
                if let range = errorMessage.range(of: "https://console.firebase.google.com") {
                    indexURL = String(errorMessage[range.lowerBound...])
                    if let endRange = indexURL.range(of: "\"", options: .literal) {
                        indexURL = String(indexURL[..<endRange.lowerBound])
                    }
                }
                
                // Throw a more informative error
                throw NSError(
                    domain: "ExpenseService",
                    code: 9,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Missing Firestore index for expenses query. Create the index using this link: \(indexURL)",
                        "indexURL": indexURL
                    ]
                )
            }
            throw error
        }
    }
    
    // Update an expense with access control
    func updateExpense(_ expense: Expense) async throws {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ExpenseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Verify the user is a member of the expense's group
        let groupRef = db.collection("groups").document(expense.groupId)
        let group = try await groupRef.getDocument(as: Group.self)
        
        // Check if the current user is a member of this group
        guard group.memberIds.contains(currentUser.uid) else {
            throw NSError(domain: "ExpenseService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You are not a member of this expense's group"])
        }
        
        // Additional check: only the creator or group creator can update the expense
        let originalExpense = try await getExpense(expenseId: expense.id)
        if originalExpense.createdBy != currentUser.uid && group.createdBy != currentUser.uid {
            throw NSError(domain: "ExpenseService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the expense creator or group admin can update this expense"])
        }
        
        try db.collection("expenses").document(expense.id).setData(from: expense)
    }
    
    // Delete an expense with access control
    func deleteExpense(expenseId: String) async throws {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ExpenseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the expense first to check permissions
        let expense = try await getExpense(expenseId: expenseId)
        
        // Get the group to check if user is admin
        let groupRef = db.collection("groups").document(expense.groupId)
        let group = try await groupRef.getDocument(as: Group.self)
        
        // Only the expense creator or group admin can delete the expense
        guard expense.createdBy == currentUser.uid || group.createdBy == currentUser.uid else {
            throw NSError(domain: "ExpenseService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the expense creator or group admin can delete this expense"])
        }
        
        try await db.collection("expenses").document(expenseId).delete()
    }
    
    // Get a single expense by ID with access control
    func getExpense(expenseId: String) async throws -> Expense {
        // Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "ExpenseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Get the expense
        let expense = try await db.collection("expenses").document(expenseId).getDocument(as: Expense.self)
        
        // Verify the user is a member of the expense's group
        let groupRef = db.collection("groups").document(expense.groupId)
        let group = try await groupRef.getDocument(as: Group.self)
        
        // Check if the current user is a member of this group
        guard group.memberIds.contains(currentUser.uid) else {
            throw NSError(domain: "ExpenseService", code: 403, userInfo: [NSLocalizedDescriptionKey: "You are not a member of this expense's group"])
        }
        
        return expense
    }
}