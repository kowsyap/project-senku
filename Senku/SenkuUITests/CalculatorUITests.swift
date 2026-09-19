import XCTest

/// The calculator used to open pre-filled and show a complete plan for a person
/// who had entered nothing. These pin the new contract: blank until asked,
/// answered only on request.
final class CalculatorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchOnCalculator() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        app.open("Quick calc")
        return app
    }

    @MainActor
    private func fill(_ app: XCUIApplication, _ identifier: String, _ value: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "missing \(identifier)")
        field.tap()
        field.typeText(value)
    }

    @MainActor
    func testOpensEmptyWithNoPlanAlreadyWorkedOut() {
        let app = launchOnCalculator()

        XCTAssertTrue(app.buttons["Calculate"].waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.buttons["Recalculate"].exists,
            "Nothing should have been calculated yet"
        )
        // An empty text field reports its placeholder as its value, so the
        // em dash here *is* emptiness rather than a number.
        for field in ["field.age", "field.height", "field.weight"] {
            XCTAssertEqual(app.textFields[field].value as? String, "—", "\(field) should start empty")
        }
        XCTAssertFalse(app.buttons["Save as my profile"].exists)
    }

    @MainActor
    func testCalculatingNeedsEveryRequiredFieldAndThenOffersToSave() {
        let app = launchOnCalculator()

        // Asking with gaps explains itself rather than silently refusing.
        app.buttons["Calculate"].tap()
        XCTAssertFalse(app.buttons["Save as my profile"].exists, "No plan from an empty form")

        fill(app, "field.age", "30")
        fill(app, "field.height", "180")
        fill(app, "field.weight", "80")
        app.buttons["Calculate"].firstMatch.tap()

        XCTAssertTrue(
            app.buttons["Save as my profile"].waitForExistence(timeout: 5),
            "A complete form should produce a plan, and a way to keep it"
        )
        XCTAssertTrue(app.buttons["Recalculate"].exists)
    }
}
