import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// A past day is judged by the target it had, not today's.
@MainActor
@Suite struct TargetHistoryTests {
    private let calendar = Calendar.current

    private func day(_ ago: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: -ago, to: .now)!)
    }

    private func history(_ defaults: UserDefaults) -> TargetHistory<FoodTargets> {
        TargetHistory(key: "test", defaults: defaults, calendar: calendar)
    }

    private func fresh() -> UserDefaults { UserDefaults(suiteName: UUID().uuidString)! }

    @Test func eachDayGetsTheTargetInForceOnIt() {
        let log = history(fresh())
        log.record(FoodTargets(calories: 2000, proteinGrams: 150), on: day(10))
        log.record(FoodTargets(calories: 2400, proteinGrams: 160), on: day(3))

        #expect(log.value(on: day(5))?.calories == 2000)
        #expect(log.value(on: day(3))?.calories == 2400)
        #expect(log.value(on: day(0))?.calories == 2400)
        // Before anything was kept: the earliest known.
        #expect(log.value(on: day(30))?.calories == 2000)
    }

    @Test func aSecondChangeTheSameDayReplacesTheFirst() {
        let log = history(fresh())
        log.record(FoodTargets(calories: 2000, proteinGrams: 150), on: day(5))
        log.record(FoodTargets(calories: 2200, proteinGrams: 150), on: day(0))
        log.record(FoodTargets(calories: 2300, proteinGrams: 150), on: day(0))

        #expect(log.value(on: day(0))?.calories == 2300)
        #expect(log.value(on: day(1))?.calories == 2000)
    }

    /// The bug: accepting a new maintenance broke every streak day before it.
    @Test func changingTheTargetLeavesEarlierStreakDaysAlone() throws {
        let defaults = fresh()
        let store = IntakeStore(defaults: defaults, calendar: calendar)
        var profile = ProfileStore.Profile(
            metrics: try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 84),
            activityLevel: .moderate,
            goal: .moderateCut,
            formula: .automatic,
            unitSystem: .metric
        )

        // Three days eaten exactly to the old target.
        let old = try #require(profile.plan.macros)
        store.recordTargets(profile: profile, on: day(5))
        for ago in 1 ... 3 {
            store.add(try IntakeEntry(date: day(ago).addingTimeInterval(12 * 3600), carbsG: old.calories / 4))
        }
        #expect(store.calorieDays(profile: profile).count == 3)

        // A new maintenance, 600 kcal higher, from today.
        profile.measuredMaintenanceCalories = profile.plan.energy.maintenanceCalories + 600
        store.recordTargets(profile: profile)

        #expect(store.calorieDays(profile: profile).count == 3)
    }
}
