//
//  Users.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-12.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct User: Codable {
    let uid: String
    var displayName: String?
    let email: String
    var groupIds: [String]
    let createdAt: Timestamp
    var lastActive: Timestamp
}
