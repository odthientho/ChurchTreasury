import XCTest

/// Smoke test for the Sunday collection entry flow.
final class OfferingFlowUITests: XCTestCase {
    @MainActor
    func testAddCheckEntryAndLooseCash() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestReset"]
        app.launch()

        // The quick button opens straight to the manual entry fields (with
        // scan shortcuts offered below) — no extra tap needed.
        app.buttons["Checks"].firstMatch.tap()
        resolveDepositedChoiceIfPresent(in: app)

        // Quick-add: donor name, check number, amount.
        let donorField = app.textFields["Donor name (leave blank if anonymous)"]
        XCTAssertTrue(donorField.waitForExistence(timeout: 5))
        donorField.tap()
        donorField.typeText("Nguyen Van A")

        let checkField = app.textFields["Check #"]
        checkField.tap()
        checkField.typeText("1101")

        let amountField = app.textFields["Amount"].firstMatch
        amountField.tap()
        amountField.typeText("250.75")

        app.buttons["Add"].firstMatch.tap()

        // The checks total (pinned near the top, above the loose-cash bill
        // form) updates immediately — this doesn't require scrolling to the
        // Entries section further down, which XCUITest may not have
        // instantiated yet since List rows load lazily.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '250.75'"))
            .firstMatch.waitForExistence(timeout: 5))

        // Second entry for the same donor should autocomplete.
        let donorField2 = app.textFields["Donor name (leave blank if anonymous)"]
        donorField2.tap()
        donorField2.typeText("Nguyen")
        let suggestion = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Nguyen Van A'")).firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 3))

        // Regression guard: SwiftData relationship changes (like linking a new
        // DonationEntry to its batch) don't propagate to other @Query-backed
        // views without an explicit context.save() — without it, the
        // Offerings list shows a stale total for a week that actually has
        // entries. Going back to the list must show this entry's amount
        // (checked by value, not by "no $0.00 anywhere", since other tests
        // sharing this install may leave unrelated empty batches behind).
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Sunday,'"))
            .firstMatch.waitForExistence(timeout: 5))
        // Give the NavigationStack pop transition (~0.35s) and the list's
        // re-render time to settle before reading the total.
        sleep(1)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '250.75'"))
            .firstMatch.exists)
    }
}
