//
//  CreateCategoryView.swift
//  frilling
//
//  Created by Josiah Ledbetter on 2024-03-15.
//

import SwiftUI
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


struct CreateCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var title: String = ""
    @Query private var categories: [ExpenseCategory]
    
    var body: some View {
        List {
            Section("Category Title") {
                TextField("Enter title here",
                          text: $title)
                Button("Add Category") {
                    withAnimation {
                        let category = ExpenseCategory(title: title)
                        modelContext.insert(category)
                        // I'm not sure why we have to set category to empty array here
                        // but title must be reset to "" or you live with some weird erros
                        // and a fucked up UI.
                        category.items = []
                        title = ""
                    }
                }
                .disabled(title.isEmpty)
            }
            Section("Existing Categories") {
                ForEach(categories) { category in
                    Text(category.title)
                                        
                    Button(role: .destructive) {
                        withAnimation {
                            modelContext.delete(category)
                        }
                    } label: {
                        Label("delete", systemImage: "trash")
                            .symbolVariant(.circle.fill)
                    }
                }
            }
        }
        .navigationTitle("Add Category")
        .toolbar {
            
            ToolbarItem(placement: .cancellationAction) {
                Button("Dismiss") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    CreateCategoryView()
}
