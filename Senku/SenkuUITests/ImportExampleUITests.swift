import XCTest

/// `docs/import-example.json` through the app's own Import Data, on a fresh
/// install: the summary it reports, then every page the file fills.
///
/// The unit tests already prove each section decodes and lands in its store;
/// this is the same file as somebody would see it. Screenshots are attached to
/// the result, and written to `SENKU_SHOTS` when that is set:
///
///     TEST_RUNNER_SENKU_SHOTS=/tmp/shots xcodebuild test … -only-testing:SenkuUITests/ImportExampleUITests
final class ImportExampleUITests: XCTestCase {
    private static let example = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // SenkuUITests
        .deletingLastPathComponent()      // Senku
        .deletingLastPathComponent()      // the repo
        .appendingPathComponent("docs/import-example.json")

    func testTheExampleImportsAndEveryPageShowsIt() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        // The debug hook that hands a file to Import Data as if it had been
        // picked — the same path, past the system picker a test cannot drive.
        app.launchEnvironment["SENKU_PLAN_FILE"] = ProcessInfo.processInfo.environment["SENKU_EXAMPLE"] ?? Self.example.path
        app.launch()

        // The restored settings switch reminders on, which asks for
        // notifications — a system prompt, in front of the app's own.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            let allow = springboard.alerts.buttons["Allow"]
            guard allow.waitForExistence(timeout: 4) else { break }
            allow.tap()
        }

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 15), "No import summary")
        shoot("00-import-summary")
        let summary = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
        XCTAssertFalse(summary.localizedCaseInsensitiveContains("could not"), summary)
        alert.buttons.firstMatch.tap()

        let pages = [
            "Me", "Weight", "Workout", "PRs", "Water", "Food",
            "Watchlist", "Dues", "Expenses", "Income", "Rest", "Plate Calculator",
        ]
        for (index, page) in pages.enumerated() {
            // From Me each time: a page can have a "More" of its own — Food's
            // menu — that the bar's would otherwise be confused with.
            if page != "Me" { app.buttons["Me"].firstMatch.tap() }
            app.open(page)
            shoot(String(format: "%02d-%@", index + 1, page))
        }
    }

    private func shoot(_ name: String) {
        Thread.sleep(forTimeInterval: 1.2)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder = ProcessInfo.processInfo.environment["SENKU_SHOTS"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
        }
    }
}
