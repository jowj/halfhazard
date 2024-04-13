//
//  CreateCategoryView.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2024-03-30.
//

import SwiftUI
import SwiftData

struct ManageGroupsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var groupName: String = ""
    @Query private var groups: [Group]
    
    var body: some View {
        
        List {

            TextField("What is your group name?",
                      text: $groupName)
            Button("Add Group") {
                withAnimation {
                    save()
                }
            }
            .disabled(groupName.isEmpty)
            .tint(.green)
            
            Section("Existing Groups") {
                if groups.isEmpty {
                        HStack {
                            ContentUnavailableView("No groups exist.",
                            systemImage: "archivebox")
                        }
                } else {
                    ForEach(groups) { group in
                        HStack {
                            Text(group.name)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            modelContext.delete(group)
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
        .navigationTitle("Manage groups")
        .toolbar {
            
            ToolbarItem(placement: .cancellationAction) {
                Button("Dismiss") {
                    dismiss()
                }
            }
        }
    }
}

private extension ManageGroupsView {
    
    func save() {
        let group = Group(name: groupName)
        modelContext.insert(group)
        // I'm not sure why we have to set category to empty array here
        // but title must be reset to "" or you live with some weird erros
        // and a fucked up UI.
        group.members = []
        groupName = ""
    }
    
}

#Preview {
    ManageGroupsView()
}
