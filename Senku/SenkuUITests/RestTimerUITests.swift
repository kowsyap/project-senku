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
        app.open("Rest")
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

    /// The chime and haptic hang off the running→finished edge, so this checks
    /// that edge is actually reached by a live app rather than only in the
    /// engine's unit tests. The simulator has no haptics and the sound cannot
    /// be asserted on, but if this passes, `Feedback.restFinished()` ran.
    @MainActor
    func testATimerActuallyReachesTheFinishedState() {
        let app = launchOnRestTab()

        // Tapping a preset starts it, and the stepper re-aims a running timer,
        // so this is already counting down from the shortest interval the
        // stepper reaches. There is no Start to press.
        app.buttons["preset.sixtySeconds"].tap()
        let shorter = app.buttons["Shorter"]
        for _ in 0..<3 { shorter.tap() }
        XCTAssertTrue(app.buttons["Pause"].exists, "A preset tap should already be running")

        XCTAssertTrue(
            app.buttons["Go again"].waitForExistence(timeout: 30),
            "The timer never crossed into finished, so nothing would have chimed"
        )
        XCTAssertEqual(remainingValue(app), "Rest finished")
    }

    /// A rest held only in `@State` is lost if iOS reclaims the app mid-set —
    /// which looked especially wrong once the Live Activity kept counting on
    /// the lock screen after the app itself had forgotten.
    @MainActor
    func testARunningRestSurvivesTheAppBeingKilled() {
        let app = launchOnRestTab()
        app.buttons["preset.threeMinutes"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 3))

        app.terminate()

        app.launch()
        app.open("Rest")

        XCTAssertTrue(
            app.buttons["Pause"].waitForExistence(timeout: 5),
            "The rest should still be running after a relaunch"
        )
        let value = remainingValue(app)
        XCTAssertFalse(value.contains("3 minutes"), "It should have kept counting, got \(value)")
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
