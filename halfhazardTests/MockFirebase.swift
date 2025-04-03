//
//  MockFirebase.swift
//  halfhazardTests
//
//  Created by Claude on 2025-03-23.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import XCTest
@testable import halfhazard

// MARK: - Protocol-based mocking approach

// Auth protocols
protocol AuthProviding {
    var currentUser: FirebaseAuth.User? { get }
    func signIn(withEmail email: String, password: String) async throws -> FirebaseAuth.AuthDataResult
    func createUser(withEmail email: String, password: String) async throws -> FirebaseAuth.AuthDataResult
    func signOut() throws
}

extension Auth: AuthProviding {}

// User protocols
protocol UserProviding {
    var uid: String { get }
    var email: String? { get }
    var displayName: String? { get }
    func delete() async throws
}

extension FirebaseAuth.User: UserProviding {}

// Simplified structure for mocking
class MockAuthDataResult {
    let user: UserProviding
    
    init(user: UserProviding) {
        self.user = user
    }
}

// MARK: - Mock implementations

class MockUserProvider: UserProviding {
    let uid: String
    let email: String?
    let displayName: String?
    var deleteError: Error?
    
    init(uid: String, email: String?, displayName: String?) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
    }
    
    func delete() async throws {
        if let error = deleteError {
            throw error
        }
    }
}

// MARK: - Firestore mocking

// Protocol-based approach for Firestore
protocol FirestoreProviding {
    func collection(_ collectionPath: String) -> CollectionReferenceProviding
}

protocol CollectionReferenceProviding {
    func document(_ documentPath: String) -> DocumentReferenceProviding
    func document() -> DocumentReferenceProviding
    func whereField(_ field: String, isEqualTo value: Any) -> QueryProviding
    func getDocuments() async throws -> QuerySnapshotProviding
}

protocol DocumentReferenceProviding {
    var documentID: String { get }
    func getDocument<T: Decodable>(as type: T.Type) async throws -> T
    func getDocument() async throws -> DocumentSnapshotProviding
    func setData(from encodable: Encodable, merge: Bool) throws
    func setData(_ documentData: [String: Any], merge: Bool) async throws
    func updateData(_ fields: [AnyHashable: Any]) async throws
    func delete() async throws
}

protocol QueryProviding {
    func order(by field: String, descending: Bool) -> QueryProviding
    func getDocuments() async throws -> QuerySnapshotProviding
}

protocol DocumentSnapshotProviding {
    var exists: Bool { get }
    var documentID: String { get }
    func data() -> [String: Any]?
    func data<T: Decodable>(as type: T.Type) throws -> T
}

protocol QuerySnapshotProviding {
    var documents: [QueryDocumentSnapshotProviding] { get }
}

protocol QueryDocumentSnapshotProviding: DocumentSnapshotProviding {}

// MARK: - Mock implementations for Firestore

class MockFirestoreProvider: FirestoreProviding {
    var collections: [String: MockCollectionProvider] = [:]
    
    func collection(_ collectionPath: String) -> CollectionReferenceProviding {
        if let existingCollection = collections[collectionPath] {
            return existingCollection
        }
        
        let newCollection = MockCollectionProvider(path: collectionPath)
        collections[collectionPath] = newCollection
        return newCollection
    }
}

class MockCollectionProvider: CollectionReferenceProviding {
    var documents: [String: MockDocumentProvider] = [:]
    var path: String
    
    init(path: String) {
        self.path = path
    }
    
    func document(_ documentPath: String) -> DocumentReferenceProviding {
        if let existingDocument = documents[documentPath] {
            return existingDocument
        }
        
        let newDocument = MockDocumentProvider(path: "\(path)/\(documentPath)", id: documentPath)
        documents[documentPath] = newDocument
        return newDocument
    }
    
    func document() -> DocumentReferenceProviding {
        let documentId = UUID().uuidString
        let newDocument = MockDocumentProvider(path: "\(path)/\(documentId)", id: documentId)
        documents[documentId] = newDocument
        return newDocument
    }
    
    func whereField(_ field: String, isEqualTo value: Any) -> QueryProviding {
        return MockQueryProvider(collection: self, filter: (field, value))
    }
    
    func getDocuments() async throws -> QuerySnapshotProviding {
        return MockQuerySnapshotProvider(documents: documents.values.map { $0 })
    }
}

class MockQueryProvider: QueryProviding {
    let collection: MockCollectionProvider
    var filter: (String, Any)?
    var sortField: String?
    var sortDescending: Bool = false
    
    init(collection: MockCollectionProvider, filter: (String, Any)? = nil) {
        self.collection = collection
        self.filter = filter
    }
    
    func order(by field: String, descending: Bool = false) -> QueryProviding {
        let query = MockQueryProvider(collection: collection, filter: filter)
        query.sortField = field
        query.sortDescending = descending
        return query
    }
    
    func getDocuments() async throws -> QuerySnapshotProviding {
        var documents = collection.documents.values.map { $0 }
        
        // Apply filter if it exists
        if let (field, value) = filter {
            documents = documents.filter { doc in
                if let data = doc.data, let fieldValue = data[field] {
                    return "\(fieldValue)" == "\(value)"
                }
                return false
            }
        }
        
        // Apply sorting if it exists
        if let sortField = sortField {
            documents.sort { doc1, doc2 in
                guard let data1 = doc1.data, let data2 = doc2.data,
                      let value1 = data1[sortField], let value2 = data2[sortField] else {
                    return false
                }
                
                if let timestamp1 = value1 as? Timestamp, let timestamp2 = value2 as? Timestamp {
                    return sortDescending ? timestamp1.dateValue() > timestamp2.dateValue() : timestamp1.dateValue() < timestamp2.dateValue()
                }
                
                if let string1 = value1 as? String, let string2 = value2 as? String {
                    return sortDescending ? string1 > string2 : string1 < string2
                }
                
                return false
            }
        }
        
        return MockQuerySnapshotProvider(documents: documents)
    }
}

class MockDocumentProvider: DocumentReferenceProviding {
    var path: String
    var documentID: String
    var data: [String: Any]?
    var exists: Bool = false
    var mockError: Error?
    
    init(path: String, id: String, data: [String: Any]? = nil, error: Error? = nil) {
        self.path = path
        self.documentID = id
        self.data = data
        self.mockError = error
    }
    
    func setData(from encodable: Encodable, merge: Bool = false) throws {
        if let error = mockError {
            throw error
        }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(encodable)
        let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        self.data = dictionary
        self.exists = true
    }
    
    func setData(_ documentData: [String: Any], merge: Bool = false) async throws {
        if let error = mockError {
            throw error
        }
        
        self.data = documentData
        self.exists = true
    }
    
    func updateData(_ fields: [AnyHashable: Any]) async throws {
        if let error = mockError {
            throw error
        }
        
        if data == nil {
            data = [:]
        }
        
        for (key, value) in fields {
            if let key = key as? String {
                // Special case for FieldValue
                if let fieldValue = value as? MockFieldValue {
                    if fieldValue.isArrayUnion, let values = fieldValue.values as? [Any] {
                        var array = data?[key] as? [Any] ?? []
                        for val in values {
                            if let stringVal = val as? String, !(array.contains { ($0 as? String) == stringVal }) {
                                array.append(val)
                            }
                        }
                        data?[key] = array
                    } else if fieldValue.isArrayRemove, let values = fieldValue.values as? [Any] {
                        var array = data?[key] as? [Any] ?? []
                        array = array.filter { item in
                            if let itemString = item as? String, let valString = values.first as? String {
                                return itemString != valString
                            }
                            return true
                        }
                        data?[key] = array
                    }
                } else {
                    data?[key] = value
                }
            }
        }
    }
    
    func delete() async throws {
        if let error = mockError {
            throw error
        }
        
        self.data = nil
        self.exists = false
    }
    
    func getDocument<T>(as modelType: T.Type) async throws -> T where T : Decodable {
        if let error = mockError {
            throw error
        }
        
        guard let data = self.data, self.exists else {
            throw NSError(domain: "MockFirestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Document does not exist"])
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let decoder = JSONDecoder()
        return try decoder.decode(modelType, from: jsonData)
    }
    
    func getDocument() async throws -> DocumentSnapshotProviding {
        if let error = mockError {
            throw error
        }
        
        return MockDocumentSnapshotProvider(exists: exists, documentID: documentID, data: data)
    }
}

class MockDocumentSnapshotProvider: DocumentSnapshotProviding {
    let exists: Bool
    let documentID: String
    private let documentData: [String: Any]?
    
    init(exists: Bool, documentID: String, data: [String: Any]?) {
        self.exists = exists
        self.documentID = documentID
        self.documentData = data
    }
    
    func data<T>(as modelType: T.Type) throws -> T where T : Decodable {
        guard let data = documentData, exists else {
            throw NSError(domain: "MockFirestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Document does not exist"])
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let decoder = JSONDecoder()
        return try decoder.decode(modelType, from: jsonData)
    }
    
    func data() -> [String : Any]? {
        return documentData
    }
}

class MockQuerySnapshotProvider: QuerySnapshotProviding {
    var allDocuments: [MockDocumentSnapshotProvider]
    
    init(documents: [MockDocumentProvider]) {
        self.allDocuments = documents.map { 
            MockDocumentSnapshotProvider(exists: $0.exists, documentID: $0.documentID, data: $0.data)
        }
    }
    
    var documents: [QueryDocumentSnapshotProviding] {
        return allDocuments.filter { $0.exists } as! [QueryDocumentSnapshotProviding]
    }
}

extension MockDocumentSnapshotProvider: QueryDocumentSnapshotProviding {}

class MockFieldValue {
    let isArrayUnion: Bool
    let isArrayRemove: Bool
    let values: [Any]
    
    init(isArrayUnion: Bool = false, isArrayRemove: Bool = false, values: [Any]) {
        self.isArrayUnion = isArrayUnion
        self.isArrayRemove = isArrayRemove
        self.values = values
    }
    
    static func arrayUnion(_ elements: [Any]) -> MockFieldValue {
        return MockFieldValue(isArrayUnion: true, values: elements)
    }
    
    static func arrayRemove(_ elements: [Any]) -> MockFieldValue {
        return MockFieldValue(isArrayRemove: true, values: elements)
    }
}