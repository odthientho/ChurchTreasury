import XCTest

/// Walks every tab and the main sub-screens to catch runtime crashes.
final class TabSmokeUITests: XCTestCase {
    @MainActor
    func testAllTabsRender() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestReset"]
        app.launch()

        app.tabBars.buttons["Expenses"].tap()
        // Expenses draws its title in-content (like Offerings) with the nav
        // bar hidden, so assert the on-screen title rather than a nav bar.
        XCTAssertTrue(app.staticTexts["Expenses"].waitForExistence(timeout: 5))

        // Reconcile is no longer a tab — it lives inside the monthly report.
        // Reports draws its title in-content (nav bar hidden), so assert the text.
        app.tabBars.buttons["Reports"].tap()
        XCTAssertTrue(app.staticTexts["Reports"].waitForExistence(timeout: 5))
        app.buttons["Monthly Treasurer Report"].firstMatch.tap()
        // The PDF preview must appear (report generated without crashing).
        XCTAssertTrue(app.navigationBars["Monthly Treasurer Report"].waitForExistence(timeout: 5))
        // Reconcile opens from here.
        app.buttons["Reconcile"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Reconcile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Import Chase PDF statement"].exists
                      || app.staticTexts["Bank Statement"].exists)
        // Dismiss the reconcile sheet, then back out of the report.
        app.swipeDown(velocity: .fast)
        app.navigationBars["Monthly Treasurer Report"].buttons.firstMatch.tap()

        // Weekly Report picker (new in the Reports tab).
        app.buttons["Weekly Report"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Weekly Report"].waitForExistence(timeout: 5))
        app.navigationBars["Weekly Report"].buttons.firstMatch.tap()

        app.buttons["Annual Giving Statements"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Annual Giving Statements"].waitForExistence(timeout: 5))

        app.tabBars.buttons["More"].tap()
        app.buttons["Donors"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Donors"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Categories"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        // "Settings" was renamed "Church Info".
        app.buttons["Church Info"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Church Info"].waitForExistence(timeout: 5))
    }
}
