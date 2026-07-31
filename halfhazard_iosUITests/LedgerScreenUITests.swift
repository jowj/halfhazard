//
//  LedgerScreenUITests.swift
//  halfhazard_iosUITests
//

import XCTest

/// Drives the single screen against the `-demoLedger` fixtures.
///
/// The screen is the whole app now, so "does adding an expense work" is a question about the
/// app rather than about a form somewhere inside it. Fixtures rather than a real account, so
/// this needs no credentials and touches no database.
final class LedgerScreenUITests: XCTestCase {

    /// Screenshots come back through the result bundle, which is the only channel out of a
    /// test process here — see docs/rewrite-plan.md.
    private func attach(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoLedger"]
        app.launch()
        return app
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testShowsTheBalanceAndTheFeed() {
        let app = launch()

        XCTAssertTrue(app.staticTexts["Laura owes you $113.85"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Groceries"].exists)
        XCTAssertTrue(app.staticTexts["Coffee"].exists)

        // Phrased from the viewer's side: the entry Laura paid says so, on both rows.
        XCTAssertTrue(app.staticTexts["You paid"].exists)
        XCTAssertTrue(app.staticTexts["Laura paid"].exists)

        attach(app, named: "ledger")
    }

    func testAddingAnExpenseUpdatesTheBalance() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Laura owes you $113.85"].waitForExistence(timeout: 10))

        app.buttons["Add expense"].tap()
        XCTAssertTrue(app.navigationBars["New expense"].waitForExistence(timeout: 5))

        app.textFields["Amount"].tap()
        app.textFields["Amount"].typeText("40")
        app.textFields["What for?"].tap()
        app.textFields["What for?"].typeText("Parking")

        attach(app, named: "add-expense")
        app.buttons["Save"].tap()

        // $40 paid by the viewer, split evenly, moves the balance by $20.
        XCTAssertTrue(app.staticTexts["Laura owes you $133.85"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Parking"].exists)
        attach(app, named: "after-add")
    }

    /// Templates: the fixture has one, applying it writes its lines as real entries.
    func testApplyingATemplateRecordsItsLines() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Laura owes you $113.85"].waitForExistence(timeout: 10))

        // Two elements answer to "More": the overflow bar item and the menu button inside it.
        app.buttons.matching(identifier: "More").firstMatch.tap()
        let templates = app.buttons["Templates"]
        XCTAssertTrue(templates.waitForExistence(timeout: 5), "the menu should open")
        templates.tap()
        XCTAssertTrue(app.navigationBars["Templates"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Monthly bills"].exists)
        attach(app, named: "templates")

        // Rent 1800 (60/40, on you) + internet 75 + power 42, all fronted by you:
        // you are owed 720 + 37.50 + 21 = 778.50 more than before.
        app.buttons["Record $1,917.00"].tap()

        XCTAssertTrue(app.staticTexts["Laura owes you $892.35"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Rent"].exists)
        attach(app, named: "after-template")
    }

    /// The way to change your own name, which is the only way the other person ever sees it.
    func testProfileIsReachableFromTheScreen() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Laura owes you $113.85"].waitForExistence(timeout: 10))

        app.buttons.matching(identifier: "More").firstMatch.tap()
        let profile = app.buttons["Your profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 5), "the menu should offer the profile")
        profile.tap()

        XCTAssertTrue(app.staticTexts["Edit Profile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Display Name"].exists)
        attach(app, named: "profile")
    }

    func testSettlingClearsTheBalance() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Laura owes you $113.85"].waitForExistence(timeout: 10))

        app.buttons["Settle up"].tap()
        XCTAssertTrue(app.navigationBars["Settle up"].waitForExistence(timeout: 5))
        attach(app, named: "settle")

        app.buttons["Record"].tap()

        XCTAssertTrue(app.staticTexts["You're square"].waitForExistence(timeout: 10))
        attach(app, named: "after-settle")
    }
}
