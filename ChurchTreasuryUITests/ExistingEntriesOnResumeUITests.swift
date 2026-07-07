import XCTest

/// Covers resuming an already-deposited collection: the entry screen must
/// show what's already recorded (checks, envelopes, or bill counts), not
/// just start blank.
final class ExistingEntriesOnResumeUITests: XCTestCase {
    @MainActor
    func testResumedChecksCollectionShowsExistingCheckEntries() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestReset"]
        app.launch()

        // Record a check, then deposit the collection.
        app.buttons["Checks"].firstMatch.tap()
        let donorField = app.textFields["Donor name (leave blank if anonymous)"]
        donorField.tap()
        donorField.typeText("Existing Check Donor")
        app.textFields["Check #"].tap()
        app.textFields["Check #"].typeText("9001")
        app.textFields["Amount"].firstMatch.tap()
        app.textFields["Amount"].firstMatch.typeText("33.00")
        app.buttons["Add"].firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()

        let weekRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Sunday,'")).firstMatch
        weekRow.tap()
        app.buttons["Status, Open"].tap()
        app.buttons["Deposited"].tap()
        skipDepositReceiptPrompt(in: app)
        app.navigationBars.buttons.firstMatch.tap()

        // Resume via "Add to That Collection" — the existing check must
        // already be listed, not just whatever gets added in this session.
        // Wait for the dialog to fully present before tapping its buttons —
        // tapping too early (before the sheet transition finishes) can miss.
        app.buttons["Checks"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["This day's offering has already been deposited"]
            .waitForExistence(timeout: 5))
        app.buttons["Add to That Collection"].tap()

        XCTAssertTrue(app.staticTexts["Existing Check Donor"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '33.00'"))
            .firstMatch.exists)
    }

    @MainActor
    func testResumedLooseCashCollectionShowsExistingBillCounts() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestReset"]
        app.launch()

        // Count some bills, then deposit the collection.
        app.buttons["Loose Cash"].firstMatch.tap()
        let tens = app.textFields.matching(NSPredicate(format: "placeholderValue == '0'")).element(boundBy: 3)
        tens.tap()
        tens.typeText("6")
        app.buttons["Done"].firstMatch.tap()

        let weekRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Sunday,'")).firstMatch
        weekRow.tap()
        app.buttons["Status, Open"].tap()
        app.buttons["Deposited"].tap()
        skipDepositReceiptPrompt(in: app)
        app.navigationBars.buttons.firstMatch.tap()

        // Resume via "Add to That Collection" — the $10 bill count of 6
        // must already show, ready to update, not reset to 0.
        app.buttons["Loose Cash"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["This day's offering has already been deposited"]
            .waitForExistence(timeout: 5))
        app.buttons["Add to That Collection"].tap()

        let tensAgain = app.textFields.matching(NSPredicate(format: "placeholderValue == '0'")).element(boundBy: 3)
        XCTAssertTrue(tensAgain.waitForExistence(timeout: 5))
        XCTAssertEqual(tensAgain.value as? String, "6")
    }
}
