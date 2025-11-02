//
//  ChangelogView.swift
//  halfhazard
//
//  Created by Claude on 2025-11-02.
//

import SwiftUI

struct ChangelogView: View {
    let entries: [ChangelogEntry]
    let isModal: Bool
    let onDismiss: (() -> Void)?

    init(entries: [ChangelogEntry], isModal: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.entries = entries
        self.isModal = isModal
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isModal {
                        // Header for modal presentation
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What's New")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                                Text("Version \(version) (Build \(build))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 8)
                    }

                    // Recent commits
                    ForEach(entries) { entry in
                        ChangelogEntryRow(entry: entry)
                    }
                }
                .padding()
            }
            .navigationTitle(isModal ? "" : "Changelog")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onDismiss?()
                        }
                    }
                }
            }
        }
    }
}

struct ChangelogEntryRow: View {
    let entry: ChangelogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.message)
                .font(.body)
                .fontWeight(.medium)

            HStack {
                Text(entry.author)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(entry.hash.prefix(7))
                .font(.caption)
                .foregroundColor(.secondary)
                .monospaced()
        }
        .padding(.vertical, 4)
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: entry.date, relativeTo: Date())
    }
}

#Preview {
    ChangelogView(
        entries: [
            ChangelogEntry(
                hash: "abc123def456",
                date: Date().addingTimeInterval(-86400),
                message: "Add splash screen on initial load",
                author: "josiah"
            ),
            ChangelogEntry(
                hash: "def456abc789",
                date: Date().addingTimeInterval(-172800),
                message: "Fix custom split UI",
                author: "josiah"
            )
        ],
        isModal: true,
        onDismiss: {}
    )
}
