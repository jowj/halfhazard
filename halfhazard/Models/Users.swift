//
//  Users.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-12.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct User: Codable, Identifiable, Hashable {
    var id: String { uid }
    let uid: String
    var displayName: String?
    var email: String
    var groupIds: [String]
    let createdAt: Timestamp
    var lastActive: Timestamp
}
