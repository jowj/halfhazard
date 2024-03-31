//
//  Utility.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-03-25.
//

import Foundation

func currentUser (users: [User], currentUserID: String) -> User {
    // Return the currently logged in user if the currentUserID field is not empty.
    // If it is, just return the first user.
    // A recipe for bugs if i ever found one.
    guard !currentUserID.isEmpty else { return users[0] } // THIS IS A DUMB HACK THAT SHOULD BREAK.
    return users.filter { user in
        user.id == currentUserID
    }[0]
}
