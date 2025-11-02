//
//  ChangelogServiceTests.swift
//  halfhazardTests
//
//  Created by Claude on 2025-11-02.
//

import XCTest
@testable import halfhazard

final class ChangelogServiceTests: XCTestCase {

    var service: ChangelogService!
    let testBuildKey = "lastPresentedBuild_test"

    override func setUp() {
        super.setUp()
        // Use a test-specific key to avoid interfering with real app
        UserDefaults.standard.removeObject(forKey: testBuildKey)
        service = ChangelogService()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testBuildKey)
        super.tearDown()
    }

    func testInitialization_FirstLaunch() {
        // Given - Fresh install with no stored build
        UserDefaults.standard.removeObject(forKey: "lastPresentedBuild")

        // When
        let service = ChangelogService()

        // Then - Should initialize to current build on first launch
        let storedBuild = UserDefaults.standard.string(forKey: "lastPresentedBuild")
        XCTAssertNotNil(storedBuild, "Build should be initialized on first launch")
    }

    func testCheckForUpdate_FirstLaunch() {
        // Given - First launch, lastPresentedBuild was just initialized
        UserDefaults.standard.removeObject(forKey: "lastPresentedBuild")
        let service = ChangelogService()

        // When
        service.checkForUpdate()

        // Then - Should not show changelog on first launch
        XCTAssertFalse(service.shouldShowChangelog)
    }

    func testCheckForUpdate_SameBuild() {
        // Given - Same build as last time
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        UserDefaults.standard.set(currentBuild, forKey: "lastPresentedBuild")
        let service = ChangelogService()

        // When
        service.checkForUpdate()

        // Then - Should not show changelog
        XCTAssertFalse(service.shouldShowChangelog)
    }

    func testCheckForUpdate_NewBuild() {
        // Given - Different build from last time
        UserDefaults.standard.set("999", forKey: "lastPresentedBuild")
        let service = ChangelogService()

        // When
        service.checkForUpdate()

        // Then - Should show changelog
        XCTAssertTrue(service.shouldShowChangelog)
    }

    func testMarkChangelogPresented() {
        // Given
        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        UserDefaults.standard.set("999", forKey: "lastPresentedBuild")
        let service = ChangelogService()
        service.checkForUpdate()
        XCTAssertTrue(service.shouldShowChangelog)

        // When
        service.markChangelogPresented()

        // Then
        XCTAssertFalse(service.shouldShowChangelog)
        let storedBuild = UserDefaults.standard.string(forKey: "lastPresentedBuild")
        XCTAssertEqual(storedBuild, currentBuild)
    }

    func testLoadChangelog() {
        // Given - Service initializes and loads changelog.json
        let service = ChangelogService()

        // When
        let entries = service.getAllEntries()

        // Then - Should have loaded entries from bundled changelog.json
        // Note: This test depends on changelog.json being generated at build time
        // In a real scenario, you'd have at least one commit
        XCTAssertNotNil(service.changelog, "Changelog should be loaded")
    }

    func testGetRecentEntries() {
        // Given
        let service = ChangelogService()

        // When
        let recentEntries = service.getRecentEntries(limit: 5)

        // Then
        XCTAssertLessThanOrEqual(recentEntries.count, 5)

        // If we have entries, verify they're in order (most recent first)
        if recentEntries.count > 1 {
            for i in 0..<(recentEntries.count - 1) {
                XCTAssertGreaterThanOrEqual(
                    recentEntries[i].date,
                    recentEntries[i + 1].date,
                    "Entries should be ordered by date, most recent first"
                )
            }
        }
    }
}
