import XCTest

/// Starts a real rest and photographs the Home Screen, so the Live Activity
/// can be confirmed to actually appear rather than merely to compile.
final class RestLiveActivityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLiveActivityAppearsAfterStartingARest() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Rest"].tap()

        app.buttons["preset.threeMinutes"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 3), "The rest should be running")

        // The Live Activity only shows once Senku is not frontmost.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 3)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "home-with-live-activity"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
