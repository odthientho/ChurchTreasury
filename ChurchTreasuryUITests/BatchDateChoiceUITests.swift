import XCTest

/// Covers the date picker atop each quick-entry screen and the choice
/// offered when the selected day is already deposited: add to that
/// collection anyway, or start a separate one for the same date.
final class BatchDateChoiceUITests: XCTestCase {
    @MainActor
    func testDepositedDayOffersAddToExistingOrSeparateCollection() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestReset"]
        app.launch()

        // Record and deposit this week's collection first.
        app.buttons["Checks"].firstMatch.tap()
        let donorField = app.textFields["Donor name (leave blank if anonymous)"]
        XCTAssertTrue(donorField.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Service date"].exists,
                      "The service date should be visible at the top of the entry screen.")
        donorField.tap()
        donorField.typeText("Vo Thi E")
        app.textFields["Check #"].tap()
        app.textFields["Check #"].typeText("5005")
        app.textFields["Amount"].firstMatch.tap()
        app.textFields["Amount"].firstMatch.typeText("55.00")
        app.buttons["Add"].firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()

        let weekRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Sunday,'")).firstMatch
        XCTAssertTrue(weekRow.waitForExistence(timeout: 5))
        weekRow.tap()
        app.buttons["Status, Open"].tap()
        app.buttons["Deposited"].tap()
        skipDepositReceiptPrompt(in: app)
        app.navigationBars.buttons.firstMatch.tap()

        // Tapping Checks again for the same (now deposited) day must prompt.
        app.buttons["Checks"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["This day's offering has already been deposited"]
            .waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add to That Collection"].exists)
        XCTAssertTrue(app.buttons["Create Separate Collection"].exists)

        app.buttons["Add to That Collection"].tap()

        // A form for that same (now-reopened) collection appears — usable
        // immediately, just like starting a brand-new entry.
        XCTAssertTrue(donorField.waitForExistence(timeout: 5))
        donorField.tap()
        donorField.typeText("Added After Deposit")
        app.textFields["Check #"].tap()
        app.textFields["Check #"].typeText("5007")
        app.textFields["Amount"].firstMatch.tap()
        app.textFields["Amount"].firstMatch.typeText("15.00")
        app.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Added After Deposit"].waitForExistence(timeout: 5))
        app.buttons["Done"].firstMatch.tap()

        // Choosing "Add to That Collection" reopened the batch: the week's
        // details page shows Open again, and both entries (the original
        // deposited one and the newly added one) are listed normally.
        let reopenedWeekRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Sunday,'")).firstMatch
        XCTAssertTrue(reopenedWeekRow.waitForExistence(timeout: 5))
        reopenedWeekRow.tap()
        XCTAssertTrue(app.staticTexts["Open"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Vo Thi E"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Added After Deposit"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOfferingsListRowShowsOnlyDateStatusAndTotal() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestReset"]
        app.launch()

        app.buttons["Checks"].firstMatch.tap()
        let donorField = app.textFields["Donor name (leave blank if anonymous)"]
        donorField.tap()
        donorField.typeText("List Row Test")
        app.textFields["Check #"].tap()
        app.textFields["Check #"].typeText("6001")
        app.textFields["Amount"].firstMatch.tap()
        app.textFields["Amount"].firstMatch.typeText("100.00")
        app.buttons["Add"].firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()

        // The list row shows the total, but not a per-method breakdown.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$100.00'"))
            .firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Checks $'"))
            .firstMatch.exists)
    }
}
