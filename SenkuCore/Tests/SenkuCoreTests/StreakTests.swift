import Foundation
import Testing
@testable import SenkuCore

/// Forgiveness, which is the one thing a finished day allows.
@Suite struct StreakForgivenessTests {
    private let calendar = Calendar.current

    private func day(_ ago: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: -ago, to: .now)!)
    }

    @Test func aGapBreaksTheRun() {
        let streak = Streak.of([day(0), day(1), day(3), day(4)])

        #expect(streak.current == 2)
        #expect(streak.longest == 2)
        #expect(streak.total == 4)
    }

    /// The whole point: the same gap, forgiven, keeps the run together.
    @Test func aForgivenDayIsSteppedOver() {
        let streak = Streak.of([day(0), day(1), day(3), day(4)], forgiven: [day(2)])

        #expect(streak.current == 4)
        #expect(streak.longest == 4)
        // Four days were kept, not five. Forgiving a day does not invent one.
        #expect(streak.total == 4)
    }

    @Test func severalForgivenDaysInARowStillBridge() {
        let streak = Streak.of([day(0), day(4), day(5)], forgiven: [day(1), day(2), day(3)])

        #expect(streak.current == 3)
        #expect(streak.total == 3)
    }

    /// Today not being done yet already did not break a run; a forgiven
    /// yesterday must not either.
    @Test func aForgivenYesterdayKeepsTodaysRunAlive() {
        let streak = Streak.of([day(2), day(3)], forgiven: [day(1)])

        #expect(streak.current == 2)
    }

    @Test func forgivingADayThatWasDoneChangesNothing() {
        let done = Streak.of([day(0), day(1), day(2)])
        let same = Streak.of([day(0), day(1), day(2)], forgiven: [day(1)])

        #expect(same == done)
    }

    /// Forgiveness cannot manufacture a streak out of nothing.
    @Test func forgivenDaysAloneAreNoStreak() {
        let streak = Streak.of([], forgiven: [day(1), day(2), day(3)])

        #expect(streak.current == 0)
        #expect(streak.longest == 0)
        #expect(streak.total == 0)
    }
}
