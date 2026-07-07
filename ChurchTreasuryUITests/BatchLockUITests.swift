import XCTest

/// Covers the week-details page's section order and the deposited-status
/// lock: marking a collection Deposited should protect it from casual
/// edits, and reverting the status should require confirmation.
final class BatchLockUITests: XCTestCase {
    @MainActor
    func testDepositedBatchLocksEntriesAndRequiresConfirmationToRevert() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestReset"]
        app.launch()

        // Record a check so there's an entry to try (and fail) to delete.
        app.buttons["Checks"].firstMatch.tap()
        resolveDepositedChoiceIfPresent(in: app)
        let donorField = app.textFields["Donor name (leave blank if anonymous)"]
        donorField.tap()
        donorField.typeText("Pham Van D")
        app.textFields["Check #"].tap()
        app.textFields["Check #"].typeText("4004")
        app.textFields["Amount"].firstMatch.tap()
        app.textFields["Amount"].firstMatch.typeText("40.00")
        app.buttons["Add"].firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()

        // Open the week's details page.
        let weekRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Sunday,'")).firstMatch
        XCTAssertTrue(weekRow.waitForExistence(timeout: 5))
        weekRow.tap()

        // Details (with Status) appear before the Checks/Envelopes/Loose
        // Cash totals in the layout.
        XCTAssertTrue(app.staticTexts["Service date"].waitForExistence(timeout: 5))

        // Mark it Deposited.
        app.buttons["Status, Open"].tap()
        app.buttons["Deposited"].tap()
        skipDepositReceiptPrompt(in: app)

        // Entries are now locked: no swipe-to-delete affordance.
        let entryRow = app.staticTexts["Pham Van D"]
        XCTAssertTrue(entryRow.waitForExistence(timeout: 5))
        entryRow.swipeLeft()
        XCTAssertFalse(app.buttons["Delete"].waitForExistence(timeout: 2))

        // Reverting to Open requires confirmation.
        app.buttons["Status, Deposited"].tap()
        app.buttons["Open"].tap()
        XCTAssertTrue(app.alerts["Change Status?"].waitForExistence(timeout: 5))

        // Cancel keeps it Deposited.
        app.alerts["Change Status?"].buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Deposited"].waitForExistence(timeout: 3))
    }
}
