//
//  ExpensesContainer.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-03-15.
//

import Foundation
import SwiftData

actor ExpensesContainer {
    
    @MainActor
    static func create(shouldCreateDefaults: inout Bool) -> ModelContainer {
    
        let schema = Schema([Expense.self])
        let configuration = ModelConfiguration()
        let container = try! ModelContainer(for: schema, configurations: configuration)
        
        if shouldCreateDefaults {
            ExpenseCategory.defaults.forEach { container.mainContext.insert($0) }
            shouldCreateDefaults = false
        }
        return container

    }
}

