//
//  AboutView.swift
//  halfhazard
//
//  Created by Claude on 2025-11-02.
//

import SwiftUI

struct AboutView: View {
    @StateObject private var changelogService = ChangelogService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App Info Section
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text("Halfhazard")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Version \(version) (Build \(build))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text("Track shared expenses with ease")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                Divider()

                // Debug Section
                #if DEBUG
                VStack(alignment: .leading, spacing: 12) {
                    Text("Debug Tools")
                        .font(.title2)
                        .fontWeight(.bold)

                    Button("Simulate Build Update (Test Modal)") {
                        // Set a fake old build number to trigger the modal on next app activation
                        UserDefaults.standard.set("0", forKey: "lastPresentedBuild")
                        print("Debug: Set lastPresentedBuild to '0' - relaunch app to see modal")
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset Changelog State") {
                        UserDefaults.standard.removeObject(forKey: "lastPresentedBuild")
                        print("Debug: Cleared lastPresentedBuild")
                    }
                    .buttonStyle(.bordered)

                    if let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        let lastBuild = UserDefaults.standard.string(forKey: "lastPresentedBuild") ?? "none"
                        Text("Current: \(currentBuild) | Last Presented: \(lastBuild)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)

                Divider()
                #endif

                // Changelog Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Changes")
                        .font(.title2)
                        .fontWeight(.bold)

                    if !changelogService.getAllEntries().isEmpty {
                        ForEach(changelogService.getAllEntries()) { entry in
                            ChangelogEntryRow(entry: entry)
                        }
                    } else {
                        Text("No changelog available")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
