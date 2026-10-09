import XCTest

/// Import a Plan, driven the way a person would: from the Week page to the
/// page itself, both converter tabs, and the preview a plan file opens.
///
/// The system file picker cannot be driven from a test, so the preview is
/// reached through the debug-only `SENKU_PLAN_FILE`, which hands the file to
/// the same code a pick does. Screenshots go to `SENKU_SHOTS` when it is set
/// (pass it as `TEST_RUNNER_SENKU_SHOTS=…` to xcodebuild), and are attached to
/// the result either way.
final class PlanImportUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func shoot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder = ProcessInfo.processInfo.environment["SENKU_SHOTS"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
        }
    }

    func testTheImportPageAndItsTwoConverters() {
        let app = XCUIApplication()
        app.launchEnvironment["SENKU_SAMPLE"] = "1"
        app.launch()

        app.open("Workout")
        app.buttons["Edit my week"].tap()

        // Below the days, the target and the rest setting: scrolled to, as a
        // person would.
        XCTAssertTrue(app.navigationBars["Your Week"].waitForExistence(timeout: 5))
        shoot("1-week-page")
        let row = app.buttons["Import a plan"]
        for _ in 0..<6 where !(row.exists && row.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(row.exists && row.isHittable, "Import a plan is not on the Week page")
        shoot("1b-week-page-import-row")
        row.tap()

        XCTAssertTrue(app.buttons["Import plan (.json)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Paste it into an AI chat."].exists)
        shoot("2-import-prompt-tab")

        app.buttons["AI skill"].tap()
        XCTAssertTrue(app.staticTexts["Install the skill into your AI."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Download"].waitForExistence(timeout: 5))
        shoot("3-import-skill-tab")
    }

    func testAPlanFileOpensItsPreview() throws {
        let file = try XCTUnwrap(ProcessInfo.processInfo.environment["SENKU_PLAN_FILE"], "Pass TEST_RUNNER_SENKU_PLAN_FILE")
        let app = XCUIApplication()
        app.launchEnvironment["SENKU_SAMPLE"] = "1"
        app.launchEnvironment["SENKU_PLAN_FILE"] = file
        app.launch()

        XCTAssertTrue(app.navigationBars["Preview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Replace"].exists)
        shoot("4-preview-top")

        app.swipeUp()
        shoot("5-preview-scrolled")

        // An exercise row opens its info sheet, body map and all.
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Barbell Back Squat'")).firstMatch
        app.swipeDown()
        if row.waitForExistence(timeout: 3), row.isHittable {
            row.tap()
        } else {
            app.buttons.containing(NSPredicate(format: "label CONTAINS 'Barbell Bench Press'")).firstMatch.tap()
        }
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        shoot("6-preview-exercise-info")
        app.buttons["Done"].tap()

        // Replace, confirmed, and the week is the file's.
        app.buttons["Replace"].tap()
        app.alerts.buttons["Replace"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        shoot("7-imported")
    }
}
