import XCTest

/// The one thing the offscreen renders cannot show: that the countdown
/// actually advances in a running app.
///
/// `RestTimer` is covered exhaustively by passing it dates, so this does not
/// re-test the arithmetic. It tests the wiring — that the tick is running, that
/// it reaches the label, and that pausing stops it.
final class RestTimerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchOnRestTab() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Rest"].tap()
        return app
    }

    /// The remaining-time label, read through the ring's accessibility value.
    @MainActor
    private func ring(_ app: XCUIApplication) -> XCUIElement {
        app.otherElements["rest.remaining"]
    }

    @MainActor
    private func remainingValue(_ app: XCUIApplication) -> String {
        ring(app).value as? String ?? ""
    }

    @MainActor
    func testCountdownAdvancesWhileRunning() {
        let app = launchOnRestTab()

        app.buttons["preset.sixtySeconds"].tap()
        let first = remainingValue(app)
        XCTAssertFalse(first.isEmpty, "The ring should publish a remaining time")

        // Tapping a preset starts it, so the value must move on its own.
        let moved = NSPredicate(format: "value != %@", first)
        expectation(for: moved, evaluatedWith: ring(app))
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testPausingStopsTheCountdown() {
        let app = launchOnRestTab()

        app.buttons["preset.threeMinutes"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 2))
        app.buttons["Pause"].tap()

        let held = remainingValue(app)
        XCTAssertTrue(held.contains("paused"), "A paused ring should say so: \(held)")

        // Nothing should move while it is held.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(remainingValue(app), held, "A paused timer must not tick")

        app.buttons["Resume"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 2), "Resume returns to running")
    }

    @MainActor
    func testResetReturnsToTheFullInterval() {
        let app = launchOnRestTab()

        app.buttons["preset.ninetySeconds"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 2))

        app.buttons["Reset"].tap()
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 2), "Reset returns to idle")
        XCTAssertEqual(remainingValue(app), "1 minute 30 seconds")
    }
}
