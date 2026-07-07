import XCTest

/// Covers the entry screen opened directly from the Offerings list's Checks
/// and Envelopes quick buttons — manual fields are immediately usable, with
/// scanning offered below as a shortcut. Does not drive the system photo
/// picker (a separate process that's unreliable to automate) — the OCR
/// pipeline itself is covered end-to-end by CheckImageAnalyzerIntegrationTests
/// in the unit test target.
final class CheckScanUITests: XCTestCase {
    @MainActor
    func testChecksButtonShowsManualFormAndScanShortcutImmediately() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestReset"]
        app.launch()

        app.buttons["Checks"].firstMatch.tap()
        resolveDepositedChoiceIfPresent(in: app)
        XCTAssertTrue(app.navigationBars["Checks"].waitForExistence(timeout: 5))

        // Manual fields are on screen right away — no extra tap needed.
        XCTAssertTrue(app.textFields["Donor name (leave blank if anonymous)"].exists)
        XCTAssertTrue(app.textFields["Check #"].exists)
        XCTAssertTrue(app.textFields["Amount"].firstMatch.exists)

        // Scan shortcuts are present too, as a secondary option.
        XCTAssertTrue(app.buttons["Choose from Library"].exists)

        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Checks"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEnvelopesButtonShowsManualFormAndScanShortcutImmediately() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uiTestReset"]
        app.launch()

        app.buttons["Envelopes"].firstMatch.tap()
        resolveDepositedChoiceIfPresent(in: app)
        XCTAssertTrue(app.navigationBars["Envelopes"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.textFields["Donor name (leave blank if anonymous)"].exists)
        XCTAssertTrue(app.textFields["Envelope #"].exists)
        XCTAssertTrue(app.buttons["Choose from Library"].exists)

        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Envelopes"].waitForExistence(timeout: 5))
    }
}
