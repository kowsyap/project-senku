import XCTest
@testable import SenkuCore

/// The timer's whole reason for storing a deadline is that it has to stay
/// correct across suspension, so these tests move `now` in jumps rather than
/// waiting on a real clock. Nothing here sleeps.
final class RestTimerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    // MARK: - Counting down

    func testRunningTimerIsUnaffectedByHowLongTheAppWasAway() {
        var timer = RestTimer(preset: .twoMinutes)
        timer.start(at: start)

        // Suspended for an hour, well past the deadline.
        XCTAssertEqual(timer.remaining(at: at(3600)), 0)
        XCTAssertTrue(timer.hasFinished(at: at(3600)))

        // And a timer still mid-rest when it comes back reads the truth, not a
        // figure that stopped decrementing while the process was gone.
        var midRest = RestTimer(preset: .fiveMinutes)
        midRest.start(at: start)
        XCTAssertEqual(midRest.remaining(at: at(200)), 100)
        XCTAssertFalse(midRest.hasFinished(at: at(200)))
    }

    func testProgressRunsFromZeroToOneAndClamps() {
        var timer = RestTimer(preset: .sixtySeconds)
        XCTAssertEqual(timer.progress(at: start), 0)

        timer.start(at: start)
        XCTAssertEqual(timer.progress(at: at(15)), 0.25, accuracy: 0.0001)
        XCTAssertEqual(timer.progress(at: at(60)), 1)
        XCTAssertEqual(timer.progress(at: at(600)), 1, "Progress must not run past one")
    }

    func testExposesADeadlineOnlyWhileRunning() {
        var timer = RestTimer(preset: .sixtySeconds)
        XCTAssertNil(timer.endsAt, "An idle timer has no deadline to publish")

        timer.start(at: start)
        XCTAssertEqual(timer.endsAt, at(60))

        timer.pause(at: at(10))
        XCTAssertNil(timer.endsAt, "A paused timer has no deadline to publish")
    }

    // MARK: - Finishing

    func testRefreshReportsTheCrossingExactlyOnce() {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)

        XCTAssertFalse(timer.refresh(at: at(59)))
        XCTAssertTrue(timer.refresh(at: at(60)), "The crossing is the haptic's cue")
        XCTAssertFalse(timer.refresh(at: at(61)), "Firing twice would buzz twice")
    }

    func testFinishIsStampedAtTheDeadlineNotAtALateRefresh() throws {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)

        // The app was suspended and only noticed five minutes later.
        timer.refresh(at: at(360))

        let phase = try XCTUnwrap(
            { if case .finished(let stamp) = timer.phase { return stamp } else { return nil } }()
        )
        XCTAssertEqual(phase, at(60), "A late notice must not drag the finish time with it")
        XCTAssertEqual(timer.overrun(at: at(360)), 300)
    }

    // MARK: - Pausing

    func testPausedTimeDoesNotDecay() {
        var timer = RestTimer(preset: .twoMinutes)
        timer.start(at: start)
        timer.pause(at: at(30))

        XCTAssertEqual(timer.remaining(at: at(30)), 90)
        XCTAssertEqual(timer.remaining(at: at(30_000)), 90, "A paused timer owes nothing to the clock")

        timer.resume(at: at(30_000))
        XCTAssertEqual(timer.remaining(at: at(30_000)), 90)
        XCTAssertEqual(timer.endsAt, at(30_090))
    }

    func testPausingAnAlreadyElapsedTimerFinishesIt() {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)
        timer.pause(at: at(90))

        XCTAssertFalse(timer.isPaused, "Pausing late must not park the timer at zero")
        XCTAssertTrue(timer.hasFinished(at: at(90)))
    }

    func testPausingLeavesTheDurationAlone() {
        var timer = RestTimer(preset: .twoMinutes)
        timer.start(at: start)
        timer.pause(at: at(30))
        timer.resume(at: at(45))

        XCTAssertEqual(timer.duration, 120, "Progress is measured against what was asked for")
    }

    // MARK: - Adjusting

    func testExtendingGrowsBothTheRemainderAndTheTotal() {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)
        timer.extend(by: 30, at: at(10))

        XCTAssertEqual(timer.remaining(at: at(10)), 80)
        XCTAssertEqual(timer.duration, 90)
        // Elapsed time stays consistent across the change.
        XCTAssertEqual(timer.progress(at: at(10)), 10.0 / 90.0, accuracy: 0.0001)
    }

    func testExtendingAFinishedTimerRestartsIt() {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)
        timer.refresh(at: at(60))
        timer.extend(by: 30, at: at(60))

        XCTAssertTrue(timer.isRunning, "Adding time to a finished timer is a request for more rest")
        XCTAssertEqual(timer.remaining(at: at(60)), 30)
    }

    func testChangingDurationMidRunRestartsRatherThanKeepingAStaleDeadline() throws {
        var timer = RestTimer(preset: .fiveMinutes)
        timer.start(at: start)
        try timer.setDuration(60, at: at(10))

        XCTAssertEqual(timer.remaining(at: at(10)), 60)
        XCTAssertEqual(timer.endsAt, at(70))
    }

    func testAdjustmentsStayInsideTheAllowedRange() {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)

        timer.extend(by: -10_000, at: at(1))
        XCTAssertEqual(timer.remaining(at: at(1)), RestTimer.allowedDuration.lowerBound)

        timer.extend(by: 10_000, at: at(1))
        XCTAssertEqual(timer.remaining(at: at(1)), RestTimer.allowedDuration.upperBound)
    }

    // MARK: - Validation

    func testRejectsDurationsOutsideTheAllowedRange() {
        XCTAssertThrowsError(try RestTimer(duration: 0))
        XCTAssertThrowsError(try RestTimer(duration: 4.9))
        XCTAssertThrowsError(try RestTimer(duration: 3601))

        XCTAssertThrowsError(try RestTimer(duration: -5)) { error in
            XCTAssertEqual(error as? ValidationError, .restDurationOutOfRange(-5))
        }
    }

    func testAcceptsTheBoundsThemselves() {
        XCTAssertNoThrow(try RestTimer(duration: RestTimer.allowedDuration.lowerBound))
        XCTAssertNoThrow(try RestTimer(duration: RestTimer.allowedDuration.upperBound))
    }

    func testEveryPresetIsALegalDurationAndRoundTrips() {
        for preset in RestPreset.allCases {
            XCTAssertTrue(RestTimer.allowedDuration.contains(preset.duration), "\(preset.rawValue)")
            XCTAssertEqual(RestPreset.matching(preset.duration), preset, "\(preset.rawValue)")
        }
        XCTAssertNil(RestPreset.matching(137), "A custom duration is not a preset")
    }

    // MARK: - Restoring

    func testSurvivesACodableRoundTrip() throws {
        // This is what relaunching mid-rest, or restoring a Live Activity,
        // amounts to.
        var timer = RestTimer(preset: .threeMinutes)
        timer.start(at: start)

        let data = try JSONEncoder().encode(timer)
        let restored = try JSONDecoder().decode(RestTimer.self, from: data)

        XCTAssertEqual(restored, timer)
        XCTAssertEqual(restored.remaining(at: at(60)), 120)
    }
}
