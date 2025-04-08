//
//  SplitType.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-13.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Represents how an expense is split among group members
enum SplitType: String, Codable {
    /// Split equally among all group members
    case equal
    /// The current user owes the full amount to another group member
    case currentUserOwes
    /// The current user paid and is owed the full amount by other members
    case currentUserOwed
    /// Custom split with manually specified amounts for each person
    case custom
}

