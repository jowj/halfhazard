//
//  MockServices.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-23.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import XCTest
@testable import halfhazard

// MARK: - Mock Group Service

class MockGroupService: GroupService {
    // Override methods for testing
    var mockGroups: [Group] = []
    var mockGroupInfo: Group?
    var mockGroupMembers: [halfhazard.User] = []
    var mockError: Error?
    
    override func createGroup(groupName: String, groupDescription: String?) async throws -> Group {
        if let error = mockError {
            throw error
        }
        
        let timestamp = Timestamp()
        let newGroup = Group(
            id: UUID().uuidString,
            name: groupName,
            memberIds: ["test-user-id"],
            createdBy: "test-user-id",
            createdAt: timestamp,
            settings: Settings(name: groupDescription ?? ""),
            settled: false,
            settledAt: nil
        )
        
        mockGroups.append(newGroup)
        return newGroup
    }
    
    override func getGroupInfo(groupID: String) async throws -> Group {
        if let error = mockError {
            throw error
        }
        
        if let mockGroup = mockGroupInfo {
            return mockGroup
        }
        
        if let group = mockGroups.first(where: { $0.id == groupID }) {
            return group
        }
        
        throw NSError(domain: "GroupService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
    }
    
    override func joinGroupByCode(code: String) async throws -> Group {
        if let error = mockError {
            throw error
        }
        
        if let group = mockGroups.first(where: { $0.id == code }) {
            return group
        }
        
        let timestamp = Timestamp()
        let newGroup = Group(
            id: code,
            name: "Joined Group",
            memberIds: ["test-user-id", "other-user"],
            createdBy: "other-user",
            createdAt: timestamp,
            settings: Settings(name: ""),
            settled: false,
            settledAt: nil
        )
        
        mockGroups.append(newGroup)
        return newGroup
    }
    
    override func leaveGroup(groupID: String) async throws {
        if let error = mockError {
            throw error
        }
        
        // Just remove from mock groups
        mockGroups.removeAll { $0.id == groupID }
    }
    
    override func deleteGroup(groupID: String) async throws {
        if let error = mockError {
            throw error
        }
        
        // Just remove from mock groups
        mockGroups.removeAll { $0.id == groupID }
    }
    
    override func getGroupMembers(groupID: String) async throws -> [halfhazard.User] {
        if let error = mockError {
            throw error
        }
        
        return mockGroupMembers
    }
    
    override func renameGroup(groupID: String, newName: String) async throws {
        if let error = mockError {
            throw error
        }
        
        if let index = mockGroups.firstIndex(where: { $0.id == groupID }) {
            mockGroups[index].name = newName
        }
    }
    
    override func removeMemberFromGroup(groupID: String, userID: String) async throws {
        if let error = mockError {
            throw error
        }
        
        if let index = mockGroups.firstIndex(where: { $0.id == groupID }) {
            mockGroups[index].memberIds.removeAll { $0 == userID }
        }
        
        mockGroupMembers.removeAll { $0.uid == userID }
    }
    
    override func settleGroup(groupID: String) async throws {
        if let error = mockError {
            throw error
        }
        
        if let index = mockGroups.firstIndex(where: { $0.id == groupID }) {
            // Check if group is already settled
            if mockGroups[index].settled {
                throw NSError(domain: "GroupService", code: 400, userInfo: [NSLocalizedDescriptionKey: "This group is already settled"])
            }
            
            // Update the group
            mockGroups[index].settled = true
            mockGroups[index].settledAt = Timestamp()
        } else {
            throw NSError(domain: "GroupService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
    }
    
    override func unsettleGroup(groupID: String) async throws {
        if let error = mockError {
            throw error
        }
        
        if let index = mockGroups.firstIndex(where: { $0.id == groupID }) {
            // Check if group is already unsettled
            if !mockGroups[index].settled {
                throw NSError(domain: "GroupService", code: 400, userInfo: [NSLocalizedDescriptionKey: "This group is already unsettled"])
            }
            
            // Update the group
            mockGroups[index].settled = false
            mockGroups[index].settledAt = nil
        } else {
            throw NSError(domain: "GroupService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group not found"])
        }
    }
}

// MARK: - Mock Expense Service

class MockExpenseService: ExpenseService {
    // Override methods for testing
    var mockExpenses: [Expense] = []
    var mockError: Error?
    
    override func getExpensesForGroup(groupId: String) async throws -> [Expense] {
        if let error = mockError {
            throw error
        }
        
        return mockExpenses.filter { $0.groupId == groupId }
    }
    
    override func createExpense(amount: Double, description: String?, groupId: String, splitType: SplitType, splits: [String: Double], customSplitPercentages: [String: Double]? = nil, payments: [String: Double] = [:], settled: Bool = false, createdAt: Timestamp? = nil) async throws -> Expense {
        if let error = mockError {
            throw error
        }
        
        let newExpense = Expense(
            id: UUID().uuidString,
            amount: amount,
            description: description,
            groupId: groupId,
            createdBy: "test-user-id",
            createdAt: createdAt ?? Timestamp(),
            splitType: splitType,
            splits: splits,
            customSplitPercentages: customSplitPercentages,
            settled: settled,
            settledAt: nil
        )
        
        mockExpenses.append(newExpense)
        return newExpense
    }
    
    override func updateExpense(_ expense: Expense) async throws {
        if let error = mockError {
            throw error
        }
        
        if let index = mockExpenses.firstIndex(where: { $0.id == expense.id }) {
            mockExpenses[index] = expense
        }
    }
    
    override func deleteExpense(expenseId: String) async throws {
        if let error = mockError {
            throw error
        }
        
        mockExpenses.removeAll { $0.id == expenseId }
    }
    
    override func getExpense(expenseId: String) async throws -> Expense {
        if let error = mockError {
            throw error
        }
        
        if let expense = mockExpenses.first(where: { $0.id == expenseId }) {
            return expense
        }
        
        throw NSError(domain: "ExpenseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Expense not found"])
    }
    
    override func settleExpense(expenseId: String) async throws {
        if let error = mockError {
            throw error
        }
        
        if let index = mockExpenses.firstIndex(where: { $0.id == expenseId }) {
            // Check if expense is already settled
            if mockExpenses[index].settled {
                throw NSError(domain: "ExpenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "This expense is already settled"])
            }
            
            // Update the expense
            mockExpenses[index].settled = true
            mockExpenses[index].settledAt = Timestamp()
        } else {
            throw NSError(domain: "ExpenseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Expense not found"])
        }
    }
    
    override func unsettleExpense(expenseId: String) async throws {
        if let error = mockError {
            throw error
        }
        
        if let index = mockExpenses.firstIndex(where: { $0.id == expenseId }) {
            // Check if expense is already unsettled
            if !mockExpenses[index].settled {
                throw NSError(domain: "ExpenseService", code: 400, userInfo: [NSLocalizedDescriptionKey: "This expense is already unsettled"])
            }
            
            // Update the expense
            mockExpenses[index].settled = false
            mockExpenses[index].settledAt = nil
        } else {
            throw NSError(domain: "ExpenseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Expense not found"])
        }
    }
    
    override func getUnsettledExpensesForGroup(groupId: String) async throws -> [Expense] {
        if let error = mockError {
            throw error
        }
        
        return mockExpenses.filter { $0.groupId == groupId && !$0.settled }
    }
}

// MARK: - Mock User Service

class MockUserService: UserService {
    var mockUsers: [halfhazard.User] = []
    var mockCurrentUser: halfhazard.User?
    var mockError: Error?
    
    override func signIn(email: String, password: String) async throws -> halfhazard.User {
        if let error = mockError {
            throw error
        }
        
        if let user = mockUsers.first(where: { $0.email == email }) {
            mockCurrentUser = user
            return user
        }
        
        let newUser = halfhazard.User(
            uid: UUID().uuidString,
            displayName: nil,
            email: email,
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        mockUsers.append(newUser)
        mockCurrentUser = newUser
        return newUser
    }
    
    override func signOut() throws {
        if let error = mockError {
            throw error
        }
        
        mockCurrentUser = nil
    }
    
    override func createUser(email: String, password: String, displayName: String?) async throws -> halfhazard.User {
        if let error = mockError {
            throw error
        }
        
        let newUser = halfhazard.User(
            uid: UUID().uuidString,
            displayName: displayName,
            email: email,
            groupIds: [],
            createdAt: Timestamp(),
            lastActive: Timestamp()
        )
        
        mockUsers.append(newUser)
        mockCurrentUser = newUser
        return newUser
    }
    
    override func getUser(uid: String) async throws -> halfhazard.User {
        if let error = mockError {
            throw error
        }
        
        if let user = mockUsers.first(where: { $0.uid == uid }) {
            return user
        }
        
        throw NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
    }
    
    override func updateUser(_ user: halfhazard.User) async throws {
        if let error = mockError {
            throw error
        }
        
        if let index = mockUsers.firstIndex(where: { $0.uid == user.uid }) {
            mockUsers[index] = user
        }
    }
    
    override func deleteUser(uid: String) async throws {
        if let error = mockError {
            throw error
        }
        
        mockUsers.removeAll { $0.uid == uid }
        if mockCurrentUser?.uid == uid {
            mockCurrentUser = nil
        }
    }
    
    override func getCurrentUser() async throws -> halfhazard.User? {
        if let error = mockError {
            throw error
        }
        
        return mockCurrentUser
    }
}