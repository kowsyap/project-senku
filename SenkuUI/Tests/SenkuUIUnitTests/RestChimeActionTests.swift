import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// The routing that decides whether the end-of-rest chime is allowed to finish
/// sounding. It was cut off mid-note because a finished rest reached the same
/// branch as a cancelled one.
@Suite struct RestChimeActionTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)
    private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    private func running() -> RestTimer {
        var timer = RestTimer(preset: .sixtySeconds)
        timer.start(at: start)
        return timer
    }

    @Test func aRunningRestBooksTheChimeForItsDeadline() {
        #expect(RestChimeAction(for: running(), at: at(30)) == .schedule(at(60)))
    }

    /// The bug. At the deadline the timer moves to `.finished`, and the chime
    /// must be left to ring rather than stopped with everything else.
    @Test func reachingTheDeadlineRingsOutRatherThanStopping() {
        var timer = running()
        timer.refresh(at: at(60))

        #expect(RestChimeAction(for: timer, at: at(60)) == .ringOut)
        #expect(RestChimeAction(for: timer, at: at(61)) == .ringOut)
    }

    /// Even if nothing has called `refresh` yet: the view's tick and the audio
    /// clock are different clocks, and whichever arrives first must agree.
    @Test func passingTheDeadlineRingsOutBeforeAnythingRefreshes() {
        #expect(RestChimeAction(for: running(), at: at(60.5)) == .ringOut)
    }

    @Test func stoppingARestStopsTheChime() {
        var timer = running()
        timer.reset()

        #expect(RestChimeAction(for: timer, at: at(60)) == .stop)
    }

    @Test func pausingARestStopsTheChime() {
        var timer = running()
        timer.pause(at: at(30))

        #expect(RestChimeAction(for: timer, at: at(30)) == .stop)
    }

    @Test func anIdleTimerHasNothingToPlay() {
        #expect(RestChimeAction(for: RestTimer(preset: .sixtySeconds), at: start) == .stop)
    }
}
