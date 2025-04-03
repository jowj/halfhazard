//
//  SplitType.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-13.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum SplitType: String, Codable {
    case equal
    case percentage
    case custom
}

