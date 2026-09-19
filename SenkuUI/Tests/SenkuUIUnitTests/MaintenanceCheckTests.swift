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

    /// Weighs every day for a fortnight, losing `weeklyKG` a week.
    private func weights(weeklyKG: Double, days: Int = 16) throws -> WeightLogStore {
        let store = WeightLogStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        for ago in stride(from: days, through: 0, by: -1) {
            let weight = 84 + weeklyKG / 7 * Double(days - ago)
            store.add(try WeighIn(date: day(ago), weightKG: weight))
        }
        return store
    }

    private func intake(calories: Double, loggedDays: Int) throws -> IntakeStore {
        let store = IntakeStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        for ago in 0 ..< loggedDays {
            store.add(try IntakeEntry(date: day(ago), carbsG: calories / 4))
        }
        return store
    }

    @Test func aFortnightOfBothProducesAFinding() throws {
        let finding = MaintenanceCheck.finding(
            profile: try profile(),
            weights: try weights(weeklyKG: -0.5),
            intake: try intake(calories: 2600, loggedDays: 14)
        )

        let result = try #require(finding)
        // Losing half a kilo a week on 2,600 is about a 550 kcal daily deficit,
        // so maintenance is around 3,150 — well clear of the ~2,790 this
        // profile's formula predicts, which is what makes it worth saying.
        #expect(abs(result.measured - 3150) < 30)
        #expect(result.loggedDays == 14)
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
            intake: try intake(calories: 2200, loggedDays: 14)
        )

        #expect(finding == nil)
    }

    @Test func noProfileSaysNothing() throws {
        let finding = MaintenanceCheck.finding(
            profile: nil,
            weights: try weights(weeklyKG: -0.5),
            intake: try intake(calories: 2200, loggedDays: 14)
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
            intake: try intake(calories: formulaMaintenance, loggedDays: 14)
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
            intake: try intake(calories: 2600, loggedDays: 14)
        )
        #expect(try #require(againstFormula).formula == formula.rounded())
    }
}
