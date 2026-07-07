import XCTest

/// Covers the recurring "Regular Expense" template flow: setting one up, seeing
/// it in the list, and having it flagged as missing in the monthly report's
/// checklist so it isn't forgotten.
final class RecurringExpenseUITests: XCTestCase {
    @MainActor
    func testRecurringExpenseSetupAppearsInListAndChecklist() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestReset"]
        app.launch()

        // More → Regular Expenses (starts empty).
        app.tabBars.buttons["More"].tap()
        app.buttons["Regular Expenses"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No Regular Expenses"].waitForExistence(timeout: 5))

        // Add a template (description + payee, no amount, no default method).
        app.buttons["New Regular Expense"].tap()
        let description = app.textFields["Description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        description.tap()
        description.typeText("Electricity Bill")
        let payee = app.textFields["Payee"]
        payee.tap()
        payee.typeText("Georgia Power")
        app.buttons["Save"].tap()

        // It shows in the list.
        XCTAssertTrue(app.staticTexts["Electricity Bill"].waitForExistence(timeout: 5))

        // The Expenses tab's "Add Regular Expenses" button opens the checklist.
        app.tabBars.buttons["Expenses"].tap()
        app.buttons["Add Regular Expenses"].firstMatch.tap()

        // The checklist lists the template with a one-tap Add.
        XCTAssertTrue(app.staticTexts["Electricity Bill"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add"].firstMatch.waitForExistence(timeout: 3))
    }
}
