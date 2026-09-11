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

        XCTAssertGreaterThan(player.duration, 0.1, "An inaudible chime is the same as none")
        XCTAssertLessThan(player.duration, 2.0, "This marks an instant; it should not play over you")
    }
}
