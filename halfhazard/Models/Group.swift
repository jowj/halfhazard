//
//  Group.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-13.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct Group: Codable {
    let id: String
    let name: String
    let memberIds: [String]
    var createdBy: String // userid
    let createdAt: Timestamp
    var settings: Settings
}
