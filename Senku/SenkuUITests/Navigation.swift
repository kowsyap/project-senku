import XCTest

extension XCUIApplication {
    /// Opens a screen by name, wherever it happens to live.
    ///
    /// The bar is not a `UITabBar` — it is a row of accessibility elements with
    /// the button trait, which is why `tabBars.buttons[...]` finds nothing — and
    /// it only carries a few screens. Anything else is behind "More", exactly as
    /// it is for somebody using the app.
    func open(_ screen: String) {
        let inBar = buttons[screen]
        if inBar.waitForExistence(timeout: 2), inBar.isHittable {
            inBar.tap()
            return
        }

        buttons["More"].tap()

        let row = buttons[screen]
        XCTAssertTrue(row.waitForExistence(timeout: 2), "\(screen) is neither in the bar nor under More")
        row.tap()
    }
}
