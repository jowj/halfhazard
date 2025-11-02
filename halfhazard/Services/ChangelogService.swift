//
//  ChangelogService.swift
//  halfhazard
//
//  Created by Claude on 2025-11-02.
//

import Foundation

class ChangelogService: ObservableObject {
    private let lastPresentedBuildKey = "lastPresentedBuild"

    @Published var shouldShowChangelog = false
    @Published var changelog: Changelog?

    init() {
        loadChangelog()
        initializeLastPresentedBuildIfNeeded()
    }

    /// Initialize lastPresentedBuild on first launch
    private func initializeLastPresentedBuildIfNeeded() {
        // If lastPresentedBuild has never been set, set it to current build
        // This prevents showing changelog on first install, but allows it to show on subsequent updates
        if UserDefaults.standard.string(forKey: lastPresentedBuildKey) == nil {
            if let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                print("ChangelogService: First launch - initializing lastPresentedBuild to \(currentBuild)")
                UserDefaults.standard.set(currentBuild, forKey: lastPresentedBuildKey)
            }
        }
    }

    /// Check if changelog should be shown (build number has changed)
    func checkForUpdate() {
        guard let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            print("ChangelogService: Could not get CFBundleVersion")
            return
        }

        let lastPresentedBuild = UserDefaults.standard.string(forKey: lastPresentedBuildKey)

        print("ChangelogService: Current build = \(currentBuild)")
        print("ChangelogService: Last presented build = \(lastPresentedBuild ?? "nil")")

        // Show changelog if build has changed and we're not on first install
        if lastPresentedBuild != nil && lastPresentedBuild != currentBuild {
            print("ChangelogService: Build changed - showing changelog")
            shouldShowChangelog = true
        } else {
            print("ChangelogService: Not showing changelog (first install or same build)")
        }
    }

    /// Mark current build as presented
    func markChangelogPresented() {
        guard let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return
        }

        UserDefaults.standard.set(currentBuild, forKey: lastPresentedBuildKey)
        shouldShowChangelog = false
    }

    /// Load changelog from bundle
    private func loadChangelog() {
        guard let url = Bundle.main.url(forResource: "changelog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load changelog.json from bundle")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            changelog = try decoder.decode(Changelog.self, from: data)
        } catch {
            print("Failed to decode changelog: \(error)")
        }
    }

    /// Get recent entries (last N commits)
    func getRecentEntries(limit: Int = 10) -> [ChangelogEntry] {
        guard let changelog = changelog else { return [] }
        return Array(changelog.entries.prefix(limit))
    }

    /// Get all entries
    func getAllEntries() -> [ChangelogEntry] {
        return changelog?.entries ?? []
    }
}
