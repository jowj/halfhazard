//
//  Category.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-03-15.
//

import Foundation
import SwiftData

@Model
class ExpenseCategory {

    @Attribute(.unique) //
    var title: String
    
    var items: [Expense]?
    
    init(title: String = "") {
        self.title = title
    }
}

extension ExpenseCategory {
    
    static var defaults: [ExpenseCategory] {
        [
            .init(title: "👀 utilities"),
            .init(title: "👀 groceries"),
            .init(title: "👀 house")

        ]
    }
}
