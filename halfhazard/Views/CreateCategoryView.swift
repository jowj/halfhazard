//
//  CreateCategoryView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-03-15.
//

import SwiftUI
import SwiftData

struct CreateCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var context
        
    @State private var title: String = ""
    @Query private var categories: [ExpenseCategory]
    
    var body: some View {
        
        List {
            TextField("Enter title here",
                      text: $title)
            Button("Add Category") {
                save()
            }
            .disabled(title.isEmpty)

            Section("Existing Categories") {
                if categories.isEmpty {
                        HStack {
                            ContentUnavailableView("No categories exist.",
                            systemImage: "archivebox")
                        }
                } else {
                    ForEach(categories) { category in
                        HStack {
                            Text(category.title)
                            
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            context.delete(category)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                            .symbolVariant(.circle.fill)
                                    }
                                }
                        }
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

private extension CreateCategoryView {
    
    func save() {
        let category = ExpenseCategory(title: title)
        context.insert(category)
        // I'm not sure why we have to set category to empty array here
        // but title must be reset to "" or you live with some weird erros
        // and a fucked up UI.
        category.items = []
        title = ""
    }
    
}


#Preview {
    CreateCategoryView()
}
