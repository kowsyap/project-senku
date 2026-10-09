import XCTest

/// The README's screenshots, taken from a running app.
///
/// Skipped unless asked for. Make a person with
/// `docs/screenshots/make_persona.py`, then:
///
/// ```
/// TEST_RUNNER_SENKU_PERSONA=/path/maya.json TEST_RUNNER_SENKU_SHOTS=/path/out \
///   xcodebuild test … -only-testing:SenkuUITests/ScreenshotTests
/// ```
///
/// Start from a fresh install: the persona loads only into an empty app.
final class ScreenshotTests: XCTestCase {
    private var persona: String!
    private var folder: URL!

    override func setUpWithError() throws {
        continueAfterFailure = true
        let environment = ProcessInfo.processInfo.environment
        guard let persona = environment["SENKU_PERSONA"], let shots = environment["SENKU_SHOTS"] else {
            throw XCTSkip("Screenshots are made on request — set SENKU_PERSONA and SENKU_SHOTS.")
        }
        self.persona = persona
        folder = URL(fileURLWithPath: shots)
    }

    /// A fresh launch for every screen, so none is reached through another's
    /// leftovers.
    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SENKU_SAMPLE"] = persona
        app.launch()
        return app
    }

    private func shoot(_ name: String) {
        // Let springs and glass settle before the picture.
        Thread.sleep(forTimeInterval: 1.2)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
    }

    /// Swipes until the element is on screen; lists only build what is shown.
    @discardableResult
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        // Past it: come back the other way.
        for _ in 0..<12 where !(element.exists && element.isHittable) {
            app.swipeDown()
        }
        return element.exists && element.isHittable
    }

    private func button(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testScreens() {
        // The first launch imports the persona; give it a moment.
        var app = launch()
        Thread.sleep(forTimeInterval: 3)

        app = launch()
        app.open("Me")
        shoot("me")

        for (tab, name) in [("Water", "water"), ("Food", "food"), ("Rest", "rest"),
                            ("Weight", "weight"), ("Anime", "anime"), ("More", "more")] {
            app = launch()
            app.open(tab)
            shoot(name)
        }

        // Records, an exercise's info, and the share card.
        app = launch()
        app.open("PRs")
        shoot("records")
        let info = app.buttons["About Barbell Hip Thrust"]
        if info.waitForExistence(timeout: 3) {
            info.tap()
            shoot("exercise-info")
            app.buttons["Done"].firstMatch.tap()
            Thread.sleep(forTimeInterval: 1.5)
        }
        // The card reads as one element, so it is tapped beside its info
        // button rather than by its title.
        let about = app.buttons["About Barbell Hip Thrust"]
        if reveal(about, in: app) {
            about.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .withOffset(CGVector(dx: 160, dy: 20)).tap()
            let share = app.buttons["Share this record"]
            if share.waitForExistence(timeout: 4) {
                share.tap()
                Thread.sleep(forTimeInterval: 1.5)
                shoot("share")
            }
        }

        // Import a Plan, from the Week page.
        app = launch()
        app.open("Workout")
        app.buttons["Edit my week"].tap()
        let row = app.buttons["Import a plan"]
        if reveal(row, in: app) {
            row.tap()
            shoot("import")
        }

        // The week so far, then today's workout and the body to pick from.
        app = launch()
        app.open("Workout")
        shoot("workout-week")
        let next = button(containing: "Upper B", in: app)
        if next.waitForExistence(timeout: 3) {
            next.tap()
            shoot("workout")
            let add = app.buttons["Add an exercise"]
            if reveal(add, in: app) {
                add.tap()
                shoot("picker")
            }
        }

    }

    func testAbout() {
        let app = launch()
        app.open("More")
        app.buttons["Settings"].tap()
        let about = app.buttons["About"]
        if reveal(about, in: app) {
            about.tap()
            shoot("about")
            let notice = app.buttons.containing(NSPredicate(format: "label CONTAINS 'react-native-body-highlighter'")).firstMatch
            if reveal(notice, in: app) {
                notice.tap()
                app.swipeUp()
                shoot("about-notice")
            }
        }
    }
}
