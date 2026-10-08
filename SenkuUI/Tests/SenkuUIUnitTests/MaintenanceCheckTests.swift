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
        calendar.date(byAdding: .day, value: -ago, to: .now)!
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

    /// Weighs every day for three weeks and a day, losing `weeklyKG` a week.
    private func weights(weeklyKG: Double, days: Int = 22) throws -> WeightLogStore {
        let store = WeightLogStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        for ago in stride(from: days, through: 0, by: -1) {
            let weight = 84 + weeklyKG / 7 * Double(days - ago)
            store.add(try WeighIn(date: day(ago), weightKG: weight))
        }
        return store
    }

    /// Food on the `loggedDays` days before today — today is never counted.
    private func intake(calories: Double, loggedDays: Int) throws -> IntakeStore {
        let store = IntakeStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        for ago in 1 ... max(1, loggedDays) where loggedDays > 0 {
            store.add(try IntakeEntry(date: day(ago), carbsG: calories / 4))
        }
        return store
    }

    @Test func threeWeeksOfBothProducesAFinding() throws {
        let finding = MaintenanceCheck.finding(
            profile: try profile(),
            weights: try weights(weeklyKG: -0.5),
            intake: try intake(calories: 2600, loggedDays: 21)
        )

        let result = try #require(finding)
        // Losing half a kilo a week on 2,600 is about a 550 kcal daily deficit,
        // so maintenance is around 3,150 — well clear of the ~2,790 this
        // profile's formula predicts, which is what makes it worth saying.
        #expect(abs(result.measured - 3150) < 30)
        #expect(result.loggedDays == 21)
    }

    /// Four days of food is an estimate of what you eat on days you remember
    /// the app, which is not the same quantity.
    @Test func tooFewLoggedDaysSaysNothing() throws {
        let finding = MaintenanceCheck.finding(
            profile: try profile(),
            weights: try weights(weeklyKG: -0.5),
            intake: try intake(calories: 2200, loggedDays: 4)
        )

        #expect(finding == nil)
    }

    @Test func tooShortAWeightHistorySaysNothing() throws {
        let finding = MaintenanceCheck.finding(
            profile: try profile(),
            weights: try weights(weeklyKG: -0.5, days: 5),
            intake: try intake(calories: 2200, loggedDays: 21)
        )

        #expect(finding == nil)
    }

    @Test func noProfileSaysNothing() throws {
        let finding = MaintenanceCheck.finding(
            profile: nil,
            weights: try weights(weeklyKG: -0.5),
            intake: try intake(calories: 2200, loggedDays: 21)
        )

        #expect(finding == nil)
    }

    /// Agreement is not news. Eating at the formula's own maintenance and
    /// holding steady should produce no card at all.
    @Test func aDifferenceInsideTheNoiseSaysNothing() throws {
        let profile = try profile()
        let formulaMaintenance = profile.plan.energy.maintenanceCalories

        let finding = MaintenanceCheck.finding(
            profile: profile,
            weights: try weights(weeklyKG: 0),
            intake: try intake(calories: formulaMaintenance, loggedDays: 21)
        )

        #expect(finding == nil)
    }

    /// Accepting a measured figure moves every target that hangs off it — and
    /// the measurement is still compared against the formula next time, not
    /// against itself, or it would drift a little further each time.
    @Test func acceptingItChangesThePlanButNotTheComparison() throws {
        var profile = try profile()
        let formula = profile.plan.energy.maintenanceCalories

        profile.measuredMaintenanceCalories = formula + 400

        #expect(profile.plan.energy.maintenanceCalories == formula + 400)
        #expect(profile.plan.energy.isMaintenanceMeasured)
        #expect(profile.plan.energy.targetCalories > 0)

        let againstFormula = MaintenanceCheck.finding(
            profile: profile,
            weights: try weights(weeklyKG: -0.5),
            intake: try intake(calories: 2600, loggedDays: 21)
        )
        #expect(try #require(againstFormula).formula == formula.rounded())
    }

    /// The bug this window fixed: months of dieting, then three weeks eating
    /// at the formula's maintenance and holding steady. Only the three weeks
    /// count, and they agree with the formula — so there is nothing to say.
    @Test func aDietThatEndedBeforeTheWindowDoesNotCount() throws {
        let profile = try profile()
        let store = WeightLogStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        for ago in stride(from: 112, through: 23, by: -1) {
            store.add(try WeighIn(date: day(ago), weightKG: 92 - 0.5 / 7 * Double(112 - ago)))
        }
        for ago in stride(from: 22, through: 0, by: -1) {
            store.add(try WeighIn(date: day(ago), weightKG: 84))
        }

        let finding = MaintenanceCheck.finding(
            profile: profile,
            weights: store,
            intake: try intake(calories: profile.plan.energy.maintenanceCalories, loggedDays: 21)
        )
        #expect(finding == nil)
    }

    /// Today is still being logged; a breakfast-only day must not drag the
    /// average down.
    @Test func todayIsNotCounted() throws {
        let food = try intake(calories: 2600, loggedDays: 21)
        let without = try #require(MaintenanceCheck.finding(
            profile: try profile(), weights: try weights(weeklyKG: -0.5), intake: food
        ))

        food.add(try IntakeEntry(date: .now, carbsG: 300 / 4))
        let with = try #require(MaintenanceCheck.finding(
            profile: try profile(), weights: try weights(weeklyKG: -0.5), intake: food
        ))
        #expect(with.measured == without.measured)
        #expect(with.loggedDays == 21)
    }
}
