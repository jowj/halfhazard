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

    var title: String = ""
    var items: [Expense]? = [Expense]()
 
    init(title: String, items: [Expense]? = nil) {
        self.title = title
        self.items = items
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
