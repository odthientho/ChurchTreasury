import XCTest

/// The reimbursement-request flow: record a request from someone (before
/// paying them) via the header button; it appears in the month list badged
/// "Pending"; tapping it opens the pay form and, once saved, it becomes a
/// normal expense badged "Paid".
final class ReimbursementRequestUITests: XCTestCase {
    @MainActor
    func testRequestShowsPendingThenTapToPayShowsPaid() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestReset"]
        app.launch()

        app.tabBars.buttons["Expenses"].tap()

        // Record a request via the symbol button next to the title.
        app.buttons["Request Reimbursement"].firstMatch.tap()
        let person = app.textFields["From (who paid)"]
        XCTAssertTrue(person.waitForExistence(timeout: 5))
        person.tap()
        person.typeText("Lan Vo")
        let amount = app.textFields["0.00"].firstMatch
        amount.tap()
        amount.typeText("50.00")
        app.buttons["Save"].tap()

        // It appears in the month list, badged "Pending".
        XCTAssertTrue(app.staticTexts["Lan Vo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Pending"].waitForExistence(timeout: 3))

        // Tap it to pay — the pre-filled pay form opens; save it.
        app.staticTexts["Lan Vo"].tap()
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // Now it's a paid expense: "Paid" badge appears, "Pending" is gone.
        XCTAssertTrue(app.staticTexts["Paid"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Pending"].waitForExistence(timeout: 2))
    }
}
