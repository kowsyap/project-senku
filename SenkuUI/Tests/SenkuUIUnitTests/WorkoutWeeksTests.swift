import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// The history screen's weeks: this week loose until every planned day is
/// done, every other week a card.
@Suite struct WorkoutWeeksTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Wednesday 22 October 2025, midday UTC — the week runs Monday 20th to
    /// Sunday 26th.
    private let now = Date(timeIntervalSince1970: 1_761_134_400)

    private func day(_ offset: Int) -> Date {
        now.addingTimeInterval(Double(offset) * 86_400)
    }

    private let push = SplitDay(name: "Push", groups: [.chest], exerciseIDs: ["a"])
    private let pull = SplitDay(name: "Pull", groups: [.back], exerciseIDs: ["b"])

    private var plan: TrainingPlan { TrainingPlan(days: [push, pull]) }

    private func session(_ day: SplitDay, on date: Date) -> WorkoutSession {
        WorkoutSession(date: date, dayID: day.id, dayName: day.name, groups: day.groups, entries: [])
    }

    @Test func anOpenWeekIsListedOneByOne() {
        let layout = WorkoutHistoryLayout.make(
            history: [session(push, on: day(-1))],
            plan: plan, now: now, calendar: calendar
        )

        #expect(layout.thisWeek.count == 1)
        #expect(layout.weeks.isEmpty)
    }

    @Test func aWeekWithEveryDayDoneBecomesACard() {
        let layout = WorkoutHistoryLayout.make(
            history: [session(pull, on: day(0)), session(push, on: day(-1))],
            plan: plan, now: now, calendar: calendar
        )

        #expect(layout.thisWeek.isEmpty)
        #expect(layout.weeks.count == 1)
        #expect(layout.weeks.first?.sessions.count == 2)
    }

    /// Earlier weeks are cards whether or not they were finished.
    @Test func earlierWeeksAreCardsNewestFirst() {
        let layout = WorkoutHistoryLayout.make(
            history: [
                session(push, on: day(-1)),
                session(pull, on: day(-8)),
                session(push, on: day(-15)),
                session(pull, on: day(-16))
            ],
            plan: plan, now: now, calendar: calendar
        )

        #expect(layout.thisWeek.count == 1)
        #expect(layout.weeks.count == 2)
        #expect(layout.weeks[0].interval.start > layout.weeks[1].interval.start)
        #expect(layout.weeks[1].sessions.count == 2)
    }

    /// Monday belongs to its own week, Sunday to the one before.
    @Test func weeksRunMondayToSunday() {
        let monday = day(-2)
        let sunday = day(-3)
        let layout = WorkoutHistoryLayout.make(
            history: [session(push, on: monday), session(pull, on: sunday)],
            plan: plan, now: now, calendar: calendar
        )

        #expect(layout.thisWeek.map(\.dayName) == ["Push"])
        #expect(layout.weeks.first?.sessions.map(\.dayName) == ["Pull"])
    }

    @Test func aWeekAddsUpItsWorkouts() {
        let week = WorkoutWeek(
            interval: DateInterval(start: day(-2), duration: 7 * 86_400),
            sessions: [session(pull, on: day(0)), session(push, on: day(-1)), session(push, on: day(-2))]
        )

        #expect(week.dayIDs == [push.id, pull.id])
        #expect(week.groups == [.chest, .back])
    }
}
