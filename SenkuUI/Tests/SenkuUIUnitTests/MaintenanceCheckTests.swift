import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// The gate, which is the whole feature: the arithmetic is trivial and will
/// happily report nonsense from four days of data.
@MainActor
@Suite struct MaintenanceCheckTests {
    private let calendar = Calendar.current

    private func day(_ ago: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: -ago, to: .now)!)
    }

    /// Mid-morning on a day, as a weigh-in or a meal would be.
    private func morning(_ ago: Int) -> Date {
        day(ago).addingTimeInterval(9 * 3600)
    }

    private func profile() throws -> ProfileStore.Profile {
        ProfileStore.Profile(
            metrics: try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 84),
            activityLevel: .moderate,
            goal: .moderateCut,
            formula: .automatic,
            unitSystem: .metric
        )
    }

    /// A weigh-in on each of `days` ago, losing `weeklyKG` a week.
    private func weights(weeklyKG: Double, days: [Int]) throws -> WeightLogStore {
        let store = WeightLogStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let oldest = days.max() ?? 0
        for ago in days {
            store.add(try WeighIn(date: morning(ago), weightKG: 84 + weeklyKG / 7 * Double(oldest - ago)))
        }
        return store
    }

    private func intake(calories: Double, days: [Int]) throws -> IntakeStore {
        let store = IntakeStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        for ago in days {
            store.add(try IntakeEntry(date: morning(ago), carbsG: calories / 4))
        }
        return store
    }

    /// The fourteen days ending yesterday.
    private let fortnight = Array(1 ... 14)

    private func check(
        _ profile: ProfileStore.Profile?,
        _ weights: WeightLogStore,
        _ intake: IntakeStore,
        since ago: Int = 14
    ) -> MaintenanceCheck.Result? {
        MaintenanceCheck.check(profile: profile, weights: weights, intake: intake, since: day(ago))
    }

    private func finding(_ result: MaintenanceCheck.Result?) -> MaintenanceCheck.Finding? {
        guard case let .ready(finding, _) = result?.status else { return nil }
        return finding
    }

    private func countedDays(_ result: MaintenanceCheck.Result?) -> Int? {
        guard case let .counting(days, _, _) = result?.status else { return nil }
        return days
    }

    @Test func fourteenCompleteDaysProduceAFinding() throws {
        let result = check(
            try profile(),
            try weights(weeklyKG: -0.5, days: fortnight),
            try intake(calories: 2600, days: fortnight)
        )

        let found = try #require(finding(result))
        // Losing half a kilo a week on 2,600 is about a 550 kcal daily deficit,
        // so maintenance is around 3,150 — well clear of the ~2,790 this
        // profile's formula predicts, which is what makes it worth saying.
        #expect(abs(found.measured - 3150) < 30)
        #expect(found.firstDay == day(14))
        #expect(found.lastDay == day(1))
    }

    /// Left undecided, the suggestion follows the latest fourteen days and
    /// the count keeps going.
    @Test func anUndecidedSuggestionMovesWithEachNewDay() throws {
        let everyDay = Array(1 ... 17)
        let result = check(
            try profile(),
            try weights(weeklyKG: -0.5, days: everyDay),
            try intake(calories: 2600, days: everyDay),
            since: 17
        )

        guard case let .ready(found, days) = result?.status else {
            Issue.record("Expected a suggestion")
            return
        }
        #expect(days == 17)
        #expect(found.firstDay == day(14))
        #expect(found.lastDay == day(1))
    }

    /// A missed day while a suggestion waits takes it away, and the count
    /// starts from nothing.
    @Test func aMissedDayTakesAWaitingSuggestionAway() throws {
        let everyDay = Array(1 ... 17)
        let result = check(
            try profile(),
            try weights(weeklyKG: -0.5, days: everyDay.filter { $0 != 2 }),
            try intake(calories: 2600, days: everyDay),
            since: 17
        )

        #expect(finding(result) == nil)
        #expect(countedDays(result) == 1)
    }

    /// Thirteen days is not fourteen, however good they are.
    @Test func thirteenDaysAreStillCounting() throws {
        let result = check(
            try profile(),
            try weights(weeklyKG: -0.5, days: Array(1 ... 13)),
            try intake(calories: 2600, days: Array(1 ... 13)),
            since: 13
        )

        #expect(countedDays(result) == 13)
    }

    /// A day with food and no weigh-in breaks the run, as does the reverse.
    @Test func aMissedWeighInStartsTheCountAgain() throws {
        let result = check(
            try profile(),
            try weights(weeklyKG: -0.5, days: fortnight.filter { $0 != 5 }),
            try intake(calories: 2600, days: fortnight)
        )

        #expect(finding(result) == nil)
        #expect(countedDays(result) == 4)
    }

    @Test func aMissedDayOfFoodStartsTheCountAgain() throws {
        let result = check(
            try profile(),
            try weights(weeklyKG: -0.5, days: fortnight),
            try intake(calories: 2600, days: fortnight.filter { $0 != 10 })
        )

        #expect(countedDays(result) == 9)
    }

    /// Calories filled in afterwards, from the streak screen, mend the day.
    @Test func caloriesFilledInLaterMendTheDay() throws {
        let food = try intake(calories: 2600, days: fortnight.filter { $0 != 10 })
        food.setTotal(.calories, 2600, on: day(10))

        let result = check(try profile(), try weights(weeklyKG: -0.5, days: fortnight), food)
        #expect(finding(result) != nil)
    }

    /// Days before the count began do not count towards it.
    @Test func daysBeforeTheStartDoNotCount() throws {
        let everyDay = Array(1 ... 30)
        let result = check(
            try profile(),
            try weights(weeklyKG: -0.5, days: everyDay),
            try intake(calories: 2600, days: everyDay),
            since: 5
        )

        #expect(countedDays(result) == 5)
    }

    @Test func noProfileSaysNothing() throws {
        let result = check(
            nil,
            try weights(weeklyKG: -0.5, days: fortnight),
            try intake(calories: 2600, days: fortnight)
        )

        #expect(result == nil)
    }

    /// Agreement is not news. Eating at the plan's own maintenance and holding
    /// steady produces no suggestion — and the count starts again the day after.
    @Test func aFortnightOnTrackStartsTheCountAgain() throws {
        let profile = try profile()
        let everyDay = Array(1 ... 16)
        let result = check(
            profile,
            try weights(weeklyKG: 0, days: everyDay),
            try intake(calories: profile.plan.energy.maintenanceCalories, days: everyDay),
            since: 16
        )

        #expect(finding(result) == nil)
        #expect(countedDays(result) == 2)
        #expect(result?.cycleStart == day(2))
    }

    /// Once a measured figure is in use, the next check asks whether *it* is
    /// right. Against the formula, it would be offered back every fortnight.
    @Test func comparesAgainstTheFigureInUse() throws {
        var profile = try profile()
        let weights = try weights(weeklyKG: -0.5, days: fortnight)
        let food = try intake(calories: 2600, days: fortnight)

        let first = try #require(finding(check(profile, weights, food)))
        profile.measuredMaintenanceCalories = first.measured

        #expect(profile.plan.energy.isMaintenanceMeasured)
        #expect(finding(check(profile, weights, food)) == nil)
    }

    /// Today is still being logged, so it is never one of the fourteen — but
    /// the card does say whether it has its weigh-in and its food yet.
    @Test func todayIsReportedButNotCounted() throws {
        let weights = try weights(weeklyKG: -0.5, days: [0, 1, 2])
        let food = try intake(calories: 2600, days: [1, 2])

        let result = check(try profile(), weights, food, since: 2)
        guard case let .counting(days, weighedToday, ateToday) = result?.status else {
            Issue.record("Expected to be counting")
            return
        }
        #expect(days == 2)
        #expect(weighedToday)
        #expect(!ateToday)
    }

    @Test func theCycleStartsTodayAndRestartsOnADecision() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let cycle = MaintenanceCycleStore(defaults: defaults, calendar: calendar, now: morning(20))
        #expect(cycle.start == day(20))

        cycle.advance(to: day(25))
        #expect(cycle.start == day(20))

        cycle.restart(on: morning(0))
        #expect(cycle.start == day(0))
        #expect(MaintenanceCycleStore(defaults: defaults, calendar: calendar).start == day(0))
    }
}
