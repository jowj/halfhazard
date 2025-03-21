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
    
    // Get all expenses for a group
    func getExpensesForGroup(groupId: String) async throws -> [Expense] {
        do {
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
    
    // Update an expense
    func updateExpense(_ expense: Expense) async throws {
        try db.collection("expenses").document(expense.id).setData(from: expense)
    }
    
    // Delete an expense
    func deleteExpense(expenseId: String) async throws {
        try await db.collection("expenses").document(expenseId).delete()
    }
    
    // Get a single expense by ID
    func getExpense(expenseId: String) async throws -> Expense {
        return try await db.collection("expenses").document(expenseId).getDocument(as: Expense.self)
    }
}