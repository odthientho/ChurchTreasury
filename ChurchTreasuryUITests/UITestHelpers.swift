import XCTest

extension XCTestCase {
    /// If the "this day is already deposited" confirmation dialog appears
    /// right after tapping a quick-entry button, resolve it by creating a
    /// separate collection — keeps each test independent of whatever state
    /// earlier tests in the same run left behind for "this week's" batch.
    @MainActor
    func resolveDepositedChoiceIfPresent(in app: XCUIApplication) {
        let createSeparate = app.buttons["Create Separate Collection"]
        if createSeparate.waitForExistence(timeout: 2) {
            createSeparate.tap()
        }
    }

    /// Dismisses the "attach bank deposit receipt?" prompt that pops up right
    /// after a collection is marked Deposited, by skipping it (Cancel).
    @MainActor
    func skipDepositReceiptPrompt(in app: XCUIApplication) {
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 3) {
            cancel.tap()
        }
    }
}
