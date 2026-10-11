import XCTest

/// Every screenshot for the user guide, taken in one run per method.
final class GuideScreenshots: XCTestCase {
    private var persona: String!
    private var folder: URL!
    private static var seeded = false

    override func setUpWithError() throws {
        continueAfterFailure = true
        let env = ProcessInfo.processInfo.environment
        guard let p = env["SENKU_PERSONA"], let s = env["SENKU_SHOTS"] else {
            throw XCTSkip("Set SENKU_PERSONA and SENKU_SHOTS.")
        }
        persona = p
        folder = URL(fileURLWithPath: s)

        if !Self.seeded {
            let app = XCUIApplication()
            app.launchEnvironment["SENKU_SAMPLE"] = persona
            app.launch()
            Thread.sleep(forTimeInterval: 3)
            app.terminate()
            Self.seeded = true
        }
    }

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SENKU_SAMPLE"] = persona
        app.launch()
        return app
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 1.2)
        let shot = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: shot)
        a.name = name; a.lifetime = .keepAlways; add(a)
        try? shot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
    }

    @discardableResult
    private func reveal(_ el: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 where !(el.exists && el.isHittable) { app.swipeUp() }
        for _ in 0..<12 where !(el.exists && el.isHittable) { app.swipeDown() }
        return el.exists && el.isHittable
    }

    private func btn(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    // MARK: - Tests (alphabetical → runs in order)

    func test01_me() {
        let app = launch()
        app.open("Me")
        shoot("guide-me")
        app.swipeUp()
        shoot("guide-me-macros")
    }

    func test02_calculator() {
        let app = launch()
        app.open("Macro Calculator")
        shoot("guide-calculator")
        app.swipeUp()
        shoot("guide-calculator-results")
    }

    func test03_workoutWeek() {
        let app = launch()
        app.open("Workout")
        shoot("guide-workout-week")
    }

    func test04_workoutSession() {
        let app = launch()
        app.open("Workout")
        let day = btn("Upper A", in: app)
        if day.waitForExistence(timeout: 3) {
            day.tap()
            shoot("guide-workout-session")
        }
    }

    func test05_setLogger() {
        let app = launch()
        app.open("Workout")
        let day = btn("Upper A", in: app)
        if day.waitForExistence(timeout: 3) { day.tap() }
        let bench = btn("Dumbbell Bench Press", in: app)
        if reveal(bench, in: app) {
            bench.tap()
            shoot("guide-set-logger")
        }
    }

    func test06_bodyweightLogger() {
        let app = launch()
        app.open("Workout")
        let day = btn("Upper B", in: app)
        if day.waitForExistence(timeout: 3) { day.tap() }
        let pullUp = btn("Pull-Up", in: app)
        if reveal(pullUp, in: app) {
            pullUp.tap()
            shoot("guide-bodyweight-logger")
        }
    }

    func test07_exerciseInfo() {
        let app = launch()
        app.open("Workout")
        let day = btn("Upper A", in: app)
        if day.waitForExistence(timeout: 3) { day.tap() }
        let info = app.buttons["About Dumbbell Bench Press"]
        if reveal(info, in: app) {
            info.tap()
            shoot("guide-exercise-info")
        }
    }

    func test08_weekEditor() {
        let app = launch()
        app.open("Workout")
        let edit = app.buttons["Edit my week"]
        if edit.waitForExistence(timeout: 3) {
            edit.tap()
            shoot("guide-week-editor")
        }
    }

    func test09_picker() {
        let app = launch()
        app.open("Workout")
        let day = btn("Upper A", in: app)
        if day.waitForExistence(timeout: 3) { day.tap() }
        let addEx = app.buttons["Add an exercise"]
        if reveal(addEx, in: app) {
            addEx.tap()
            shoot("guide-picker")
        }
    }

    func test10_import() {
        let app = launch()
        app.open("Workout")
        let edit = app.buttons["Edit my week"]
        if edit.waitForExistence(timeout: 3) { edit.tap() }
        let importRow = app.buttons["Import a plan"]
        if reveal(importRow, in: app) {
            importRow.tap()
            shoot("guide-import")
        }
    }

    func test11_rest() {
        let app = launch()
        app.open("Rest")
        shoot("guide-rest")
        let start = btn("Start", in: app)
        if start.waitForExistence(timeout: 3) {
            start.tap()
            Thread.sleep(forTimeInterval: 2)
            shoot("guide-rest-running")
            let end = btn("End", in: app)
            if end.waitForExistence(timeout: 2) { end.tap() }
        }
    }

    func test12_water() {
        let app = launch()
        app.open("Water")
        shoot("guide-water")
        app.swipeUp()
        shoot("guide-water-chart")
    }

    func test13_food() {
        let app = launch()
        app.open("Food")
        shoot("guide-food")
        app.swipeUp()
        shoot("guide-food-list")
    }

    func test14_weight() {
        let app = launch()
        app.open("Weight")
        shoot("guide-weight")
        app.swipeUp()
        shoot("guide-weight-history")
    }

    func test15_records() {
        let app = launch()
        app.open("PRs")
        shoot("guide-records")
    }

    func test16_recordShare() {
        let app = launch()
        app.open("PRs")
        let aboutRecord = app.buttons["About Barbell Hip Thrust"]
        if reveal(aboutRecord, in: app) {
            aboutRecord.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .withOffset(CGVector(dx: 160, dy: 20)).tap()
            let share = app.buttons["Share this record"]
            if share.waitForExistence(timeout: 4) {
                share.tap()
                Thread.sleep(forTimeInterval: 1.5)
                shoot("guide-share-card")
            }
        }
    }

    func test17_anime() {
        let app = launch()
        app.open("Anime")
        shoot("guide-anime")
    }

    func test18_dues() {
        let app = launch()
        app.open("Dues")
        shoot("guide-dues")
    }

    func test19_plates() {
        let app = launch()
        app.open("More")
        let plates = app.buttons["Plates"]
        if plates.waitForExistence(timeout: 3) {
            plates.tap()
            shoot("guide-plates")
        }
    }

    func test20_settings() {
        let app = launch()
        app.open("More")
        app.buttons["Settings"].tap()
        shoot("guide-settings")
    }

    func test21_about() {
        let app = launch()
        app.open("More")
        app.buttons["Settings"].tap()
        let about = app.buttons["About"]
        if reveal(about, in: app) {
            about.tap()
            shoot("guide-about")
        }
    }

    func test22_more() {
        let app = launch()
        app.open("More")
        shoot("guide-more")
    }

    func test23_streaks() {
        let app = launch()
        app.open("Water")
        app.swipeUp()
        app.swipeUp()
        shoot("guide-streaks")
    }
}
