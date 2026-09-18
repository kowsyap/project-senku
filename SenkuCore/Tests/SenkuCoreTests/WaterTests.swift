import Foundation
import Testing
@testable import SenkuCore

@Suite struct WaterTests {
    private func entry(_ ml: Double, daysAgo: Int = 0) throws -> WaterEntry {
        try WaterEntry(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!,
            millilitres: ml
        )
    }

    @Test func aDayAddsUpAgainstItsGoal() throws {
        let day = WaterDay(
            date: .now,
            entries: [try entry(500), try entry(250), try entry(700)],
            goal: WaterGoal(baseML: 2450)
        )

        #expect(day.totalML == 1450)
        #expect(day.percentage == 59)
        #expect(!day.isMet)
        #expect(day.remainingML == 1000)
        #expect(day.spoken == "1,450 of 2,450 ml · 59%")
    }

    /// The bottle cannot overflow its own outline, but the overage is still
    /// reported rather than quietly dropped.
    @Test func goingOverCapsTheFractionAndKeepsTheSurplus() throws {
        let day = WaterDay(
            date: .now,
            entries: [try entry(3000)],
            goal: WaterGoal(baseML: 2450)
        )

        #expect(day.fraction == 1)
        #expect(day.isMet)
        #expect(day.overML == 550)
        #expect(day.remainingML == 0)
    }

    @Test func theGoalIsTheSumOfItsParts() {
        let goal = WaterGoal(baseML: 2450, trainingBonusML: 500, creatineBonusML: 500)

        #expect(goal.totalML == 3450)
        #expect(!goal.isOverridden)
        #expect(goal.explanation == "2450 base +500 training +500 creatine")
    }

    /// A number you set yourself is shown as yours, not dressed up as a
    /// calculation.
    @Test func anOverrideSaysItIsAnOverride() {
        let goal = WaterGoal(baseML: 2450, trainingBonusML: 500, overrideML: 3000)

        #expect(goal.totalML == 3000)
        #expect(goal.isOverridden)
        #expect(goal.explanation == "Your own target")
    }

    @Test func aDrinkHasToBeADrink() {
        #expect(throws: (any Error).self) { try WaterEntry(millilitres: 0) }
        #expect(throws: (any Error).self) { try WaterEntry(millilitres: -250) }
        #expect(throws: (any Error).self) { try WaterEntry(millilitres: 9000) }
        #expect(throws: Never.self) { try WaterEntry(millilitres: 250) }
    }

    @Test func theLogGroupsByDay() throws {
        let log = WaterLog([
            try entry(500), try entry(250),
            try entry(1000, daysAgo: 1),
            try entry(750, daysAgo: 3),
        ])

        #expect(log.totalML(on: .now) == 750)
        #expect(log.recentTotals(days: 4).map(\.totalML) == [750, 1000, 0, 750])
    }

    /// An empty day is a day you drank nothing, which is worth drawing.
    @Test func recentTotalsIncludeDaysWithNothingLogged() {
        #expect(WaterLog([]).recentTotals(days: 7).count == 7)
    }
}

@Suite struct StreakTests {
    private let calendar = Calendar.current

    private func days(_ offsets: [Int]) -> Set<Date> {
        Set(offsets.compactMap { calendar.date(byAdding: .day, value: -$0, to: .now) })
    }

    @Test func todayAndYesterdayIsARunOfTwo() {
        #expect(Streak.of(days([0, 1])).current == 2)
    }

    /// Mid-afternoon on a day you have not got to yet is not a broken streak.
    @Test func todayMissingDoesNotEndTheRun() {
        let streak = Streak.of(days([1, 2, 3]))

        #expect(streak.current == 3)
        #expect(streak.longest == 3)
    }

    @Test func aGapEndsTheCurrentRunButNotTheRecord() {
        // Five in a row a fortnight ago, two more recently, nothing yesterday.
        let streak = Streak.of(days([2, 3, 10, 11, 12, 13, 14]))

        #expect(streak.current == 0)
        #expect(streak.longest == 5)
        #expect(streak.total == 7)
    }

    @Test func nothingLoggedIsNoStreak() {
        let streak = Streak.of([])

        #expect(streak.current == 0)
        #expect(streak.longest == 0)
        #expect(streak.total == 0)
    }

    /// The same day twice cannot inflate anything: days are a set, normalised
    /// to midnight.
    @Test func duplicateTimesOnOneDayCountOnce() {
        let now = Date.now
        let later = calendar.date(byAdding: .hour, value: 6, to: calendar.startOfDay(for: now))!

        #expect(Streak.of([now, later]).current == 1)
    }
}
