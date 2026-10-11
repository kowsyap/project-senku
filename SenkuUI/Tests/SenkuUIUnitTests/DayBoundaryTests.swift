import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// A day that starts at three: a late night belongs to the day it followed.
@MainActor
@Suite struct DayBoundaryTests {
    private let base: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        base.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private var three: Calendar { DayBoundary.calendar(hour: 3, base: base, at: at(11, 12)) }

    @Test func midnightIsTheCalendarAsItWas() {
        let midnight = DayBoundary.calendar(hour: 0, base: base)
        #expect(midnight.startOfDay(for: at(11, 1, 30)) == at(11, 0))
    }

    @Test func beforeThreeBelongsToTheDayBefore() {
        #expect(three.startOfDay(for: at(11, 1, 30)) == at(10, 3))
        #expect(three.startOfDay(for: at(11, 3, 30)) == at(11, 3))
        #expect(three.isDate(at(11, 2, 59), inSameDayAs: at(10, 22)))
        #expect(!three.isDate(at(11, 3, 1), inSameDayAs: at(10, 22)))
    }

    /// A tick saved at midnight under the old boundary means the same day
    /// under the new one — and the other way round.
    @Test func aSavedDayMeansTheSameDayUnderEitherBoundary() {
        let midnight = DayBoundary.calendar(hour: 0, base: base)
        #expect(DayBoundary.day(of: at(10, 0), in: three) == at(10, 3))
        #expect(DayBoundary.day(of: at(10, 3), in: midnight) == at(10, 0))
    }

    /// A glass at half past one counts towards yesterday's water.
    @Test func lateWaterCountsTowardsTheDayBefore() {
        let store = WaterStore(defaults: UserDefaults(suiteName: UUID().uuidString)!, calendar: three)
        _ = store.add(millilitres: 500, at: at(10, 20))
        _ = store.add(millilitres: 250, at: at(11, 1, 30))
        _ = store.add(millilitres: 400, at: at(11, 9))
        #expect(store.log.totalML(on: at(10, 12)) == 750)
        #expect(store.log.totalML(on: at(11, 12)) == 400)
    }

    /// Streaks count the late night as the day before, so a streak is not
    /// broken by drinking after midnight and not before.
    @Test func streaksFollowTheBoundary() {
        let days: Set<Date> = [at(9, 10), at(11, 1)]   // the 11th at 1 am is the 10th
        let streak = Streak.of(days, on: at(10, 20), calendar: three)
        #expect(streak.current == 2)
    }

    @Test func oneAndTwoAreChoicesToo() {
        #expect(DayBoundary.choices == [0, 1, 2, 3])
        let one = DayBoundary.calendar(hour: 1, base: base, at: at(11, 12))
        #expect(one.startOfDay(for: at(11, 0, 30)) == at(10, 1))
        #expect(one.startOfDay(for: at(11, 1, 30)) == at(11, 1))
        #expect(DayBoundary.title(2) == "2 am")
    }
}
