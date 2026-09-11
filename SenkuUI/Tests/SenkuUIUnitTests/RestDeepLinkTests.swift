import XCTest
import SenkuCore
@testable import SenkuUI

/// The widget's only way of starting a rest, so a parsing slip here is a
/// widget that silently does nothing.
final class RestDeepLinkTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        defaults = UserDefaults(suiteName: "senku.test.deeplink")
        defaults.removePersistentDomain(forName: "senku.test.deeplink")
    }

    func testStartsARestAtTheRequestedDuration() throws {
        let timer = try XCTUnwrap(RestDeepLink.handle(RestDeepLink.url(seconds: 120)))
        XCTAssertEqual(timer.duration, 120)
        XCTAssertTrue(timer.isRunning)
    }

    func testTheGeneratedURLRoundTripsThroughItsOwnParser() throws {
        for preset in RestPreset.allCases {
            let timer = try XCTUnwrap(RestDeepLink.handle(RestDeepLink.url(seconds: preset.duration)))
            XCTAssertEqual(timer.duration, preset.duration, "\(preset.rawValue)")
        }
    }

    func testIgnoresURLsThatAreNotOurs() {
        XCTAssertNil(RestDeepLink.handle(URL(string: "https://example.com/rest/start?seconds=60")!))
        XCTAssertNil(RestDeepLink.handle(URL(string: "senku://profile/start?seconds=60")!))
        XCTAssertNil(RestDeepLink.handle(URL(string: "senku://rest/stop")!))
    }

    func testAnUnusableDurationStillStartsARestRatherThanDoingNothing() throws {
        // The tap was unambiguous even when the number is not.
        for bad in ["senku://rest/start", "senku://rest/start?seconds=abc",
                    "senku://rest/start?seconds=99999"] {
            let timer = try XCTUnwrap(RestDeepLink.handle(URL(string: bad)!), bad)
            XCTAssertTrue(timer.isRunning, bad)
            XCTAssertTrue(RestTimer.allowedDuration.contains(timer.duration), bad)
        }
    }
}
