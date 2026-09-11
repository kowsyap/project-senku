import XCTest
import AVFoundation
@testable import SenkuUI

/// The chime fails silently if the resource is missing from the bundle — which
/// looks exactly like "the timer didn't make a sound" and is invisible at the
/// call site. These check the file is actually there and actually decodes.
final class FeedbackTests: XCTestCase {
    func testCompletionChimeIsBundled() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "rest-complete", withExtension: "wav"),
            "The chime is missing from the bundle; the timer would finish silently"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testCompletionChimeDecodesAndIsShortEnoughToBePunctuation() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "rest-complete", withExtension: "wav"))
        let player = try AVAudioPlayer(contentsOf: url)

        // Long enough to be found when it starts while the phone is face down
        // in a bag, short enough not to still be playing when you pick it up.
        XCTAssertGreaterThan(player.duration, 1.5, "Too short to be noticed across a gym")
        XCTAssertLessThan(player.duration, 6.0, "It marks an instant; it should not play over you")
    }
}
