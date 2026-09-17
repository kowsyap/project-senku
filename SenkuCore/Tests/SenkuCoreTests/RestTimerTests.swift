import Testing
import Foundation
@testable import SenkuCore

/// The timer's whole reason for storing a deadline is that it has to stay
/// correct across suspension, so these move `now` in jumps rather than waiting
/// on a real clock. Nothing here sleeps.
@Suite("Rest timer")
struct RestTimerTests {
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    // MARK: - Counting down

    @Test("A running timer is unaffected by how long the app was away")
    func runningTimerIsUnaffectedByHowLongTheAppWasAway() {
        var timer = RestTimer(preset: .twoMinutes)
        timer.start(at: start)

        // Suspended for an hour, well past the deadline.
        #expect(timer.remaining(at: at(3600)) == 0)
        #expect(timer.hasFinished(at: at(3600)))

        // And a timer still mid-rest when it comes back reads the truth, not a
        // figure that stopped decrementing while the process was gone.
        var midRest = RestTimer(preset: .fiveMinutes)
        midRest.start(at: start)
        #expect(midRest.remaining(at: at(200)) == 100)
        #expect(!midRest.hasFinished(at: at(200)))
    }

    @Test("Progress runs from zero to one and clamps")
    func progressRunsFromZeroToOneAndClamps() {
        var timer = RestTimer(preset: .sixtySeconds)
        #expect(timer.progress(at: start) == 0)

        timer.start(at: start)
        expectClose(timer.progress(at: at(15)), 0.25, tolerance: 0.0001)
        #expect(timer.progress(at: at(60)) == 1)
        #expect(timer.progress(at: at(600)) == 1, "Progress must not run past one")
    }

    @Test("A deadline is published only while running")
    func exposesADeadlineOnlyWhileRunning() {
        var timer = RestTimer(preset: .sixtySeconds)
        #expect(timer.endsAt == nil, "An idle timer has no deadline to publish")

        timer.start(at: start)
        #expect(timer.endsAt == at(60))

        timer.pause(at: at(10))
        #expect(timer.endsAt == nil, "A paused timer has no deadline to publish")
    }

    // MARK: - Finishing

    @Test("Refresh reports the crossing exactly once")
    func refreshReportsTheCrossingExactlyOnce() {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)

        // Bound to locals because `#expect` decomposes the expression it is
        // given and cannot call a `mutating` method on the way through.
        let early = timer.refresh(at: at(59))
        let crossing = timer.refresh(at: at(60))
        let again = timer.refresh(at: at(61))

        #expect(!early)
        #expect(crossing, "The crossing is the haptic's cue")
        #expect(!again, "Firing twice would buzz twice")
    }

    @Test("The finish is stamped at the deadline, not at a late refresh")
    func finishIsStampedAtTheDeadlineNotAtALateRefresh() throws {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)

        // The app was suspended and only noticed five minutes later.
        timer.refresh(at: at(360))

        guard case .finished(let stamp) = timer.phase else {
            Issue.record("Expected a finished timer, got \(timer.phase)")
            return
        }
        #expect(stamp == at(60), "A late notice must not drag the finish time with it")
        #expect(timer.overrun(at: at(360)) == 300)
    }

    // MARK: - Pausing

    @Test("Paused time does not decay")
    func pausedTimeDoesNotDecay() {
        var timer = RestTimer(preset: .twoMinutes)
        timer.start(at: start)
        timer.pause(at: at(30))

        #expect(timer.remaining(at: at(30)) == 90)
        #expect(timer.remaining(at: at(30_000)) == 90, "A paused timer owes nothing to the clock")

        timer.resume(at: at(30_000))
        #expect(timer.remaining(at: at(30_000)) == 90)
        #expect(timer.endsAt == at(30_090))
    }

    @Test("Pausing an already elapsed timer finishes it")
    func pausingAnAlreadyElapsedTimerFinishesIt() {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)
        timer.pause(at: at(90))

        #expect(!timer.isPaused, "Pausing late must not park the timer at zero")
        #expect(timer.hasFinished(at: at(90)))
    }

    @Test("Pausing leaves the duration alone")
    func pausingLeavesTheDurationAlone() {
        var timer = RestTimer(preset: .twoMinutes)
        timer.start(at: start)
        timer.pause(at: at(30))
        timer.resume(at: at(45))

        #expect(timer.duration == 120, "Progress is measured against what was asked for")
    }

    // MARK: - Adjusting

    @Test("Extending grows both the remainder and the total")
    func extendingGrowsBothTheRemainderAndTheTotal() {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)
        timer.extend(by: 30, at: at(10))

        #expect(timer.remaining(at: at(10)) == 80)
        #expect(timer.duration == 90)
        // Elapsed time stays consistent across the change.
        expectClose(timer.progress(at: at(10)), 10.0 / 90.0, tolerance: 0.0001)
    }

    @Test("Extending a finished timer restarts it")
    func extendingAFinishedTimerRestartsIt() {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)
        timer.refresh(at: at(60))
        timer.extend(by: 30, at: at(60))

        #expect(timer.isRunning, "Adding time to a finished timer is a request for more rest")
        #expect(timer.remaining(at: at(60)) == 30)
    }

    @Test("Changing duration mid-run restarts rather than keeping a stale deadline")
    func changingDurationMidRunRestarts() throws {
        var timer = RestTimer(preset: .fiveMinutes)
        timer.start(at: start)
        try timer.setDuration(60, at: at(10))

        #expect(timer.remaining(at: at(10)) == 60)
        #expect(timer.endsAt == at(70))
    }

    @Test("Adjustments stay inside the allowed range")
    func adjustmentsStayInsideTheAllowedRange() {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)

        timer.extend(by: -10_000, at: at(1))
        #expect(timer.remaining(at: at(1)) == RestTimer.allowedDuration.lowerBound)

        timer.extend(by: 10_000, at: at(1))
        #expect(timer.remaining(at: at(1)) == RestTimer.allowedDuration.upperBound)
    }

    // MARK: - Validation

    @Test("Durations outside the allowed range are rejected", arguments: [0.0, 4.9, 3601.0, -5.0])
    func rejectsDurationsOutsideTheAllowedRange(duration: Double) {
        #expect(throws: ValidationError.restDurationOutOfRange(duration)) {
            try RestTimer(duration: duration)
        }
    }

    @Test("The bounds themselves are accepted")
    func acceptsTheBoundsThemselves() throws {
        _ = try RestTimer(duration: RestTimer.allowedDuration.lowerBound)
        _ = try RestTimer(duration: RestTimer.allowedDuration.upperBound)
    }

    @Test("Every preset is a legal duration and round trips", arguments: RestPreset.allCases)
    func everyPresetIsALegalDurationAndRoundTrips(preset: RestPreset) {
        #expect(RestTimer.allowedDuration.contains(preset.duration))
        #expect(RestPreset.matching(preset.duration) == preset)
    }

    @Test("A custom duration matches no preset")
    func customDurationMatchesNoPreset() {
        #expect(RestPreset.matching(137) == nil)
    }

    // MARK: - Restoring

    @Test("A timer survives a Codable round trip")
    func survivesACodableRoundTrip() throws {
        // This is what relaunching mid-rest, or restoring a Live Activity,
        // amounts to.
        var timer = RestTimer(preset: .threeMinutes)
        timer.start(at: start)

        let data = try JSONEncoder().encode(timer)
        let restored = try JSONDecoder().decode(RestTimer.self, from: data)

        #expect(restored == timer)
        #expect(restored.remaining(at: at(60)) == 120)
    }
}

@Suite("Restoring a stored rest")
struct RestRestoreTests {
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("A rest still running is restored")
    func runningRestIsRestored() {
        var timer = RestTimer(preset: .twoMinutes)
        timer.start(at: start)
        #expect(timer.isWorthRestoring(at: start.addingTimeInterval(30)))
    }

    @Test("A rest that has just finished is restored")
    func justFinishedRestIsRestored() {
        var timer = RestTimer(preset: .twoMinutes)
        timer.start(at: start)
        #expect(timer.isWorthRestoring(at: start.addingTimeInterval(130)))
    }

    @Test("Yesterday's finished rest is not")
    func staleRestIsNotRestored() {
        var timer = RestTimer(preset: .twoMinutes)
        timer.start(at: start)
        // Back the next morning. Nothing here is worth showing, and showing it
        // would announce a set finished hours ago.
        #expect(!timer.isWorthRestoring(at: start.addingTimeInterval(60 * 60 * 14)))
    }

    @Test("A paused rest is kept however long you were away")
    func pausedRestIsKept() {
        var timer = RestTimer(preset: .threeMinutes)
        timer.start(at: start)
        timer.pause(at: start.addingTimeInterval(20))
        // A pause is an explicit "hold this", with no deadline to go stale.
        #expect(timer.isWorthRestoring(at: start.addingTimeInterval(60 * 60 * 14)))
    }

    @Test("An idle timer is nothing to restore")
    func idleRestIsNotRestored() {
        #expect(!RestTimer(preset: .sixtySeconds).isWorthRestoring(at: start))
    }
}
