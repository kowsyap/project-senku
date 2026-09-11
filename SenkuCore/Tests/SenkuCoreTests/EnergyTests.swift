import Testing
@testable import SenkuCore

@Suite("Energy")
struct EnergyTests {
    // 30yo male, 180cm, 80kg. Mifflin: 10(80) + 6.25(180) - 5(30) + 5 = 1780
    let male: BodyMetrics
    // 30yo female, 165cm, 60kg. Mifflin: 10(60) + 6.25(165) - 5(30) - 161 = 1320.25
    let female: BodyMetrics

    init() throws {
        male = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 80)
        female = try BodyMetrics(sex: .female, age: 30, heightCM: 165, weightKG: 60)
    }

    private func profile(_ goal: Goal, _ activity: ActivityLevel = .moderate) -> EnergyProfile {
        EnergyCalculator.profile(for: male, activityLevel: activity, goal: goal)
    }

    @Test("Mifflin-St Jeor reproduces its published equation")
    func mifflinStJeorReproducesPublishedEquation() {
        expectClose(BMRFormula.mifflinStJeor.basalMetabolicRate(for: male), 1780)
        expectClose(BMRFormula.mifflinStJeor.basalMetabolicRate(for: female), 1320.25)
    }

    @Test("Katch-McArdle works from lean mass")
    func katchMcArdleWorksFromLeanMass() throws {
        // 80kg at 20% fat -> 64kg lean -> 370 + 21.6(64) = 1752.4
        let lean = try BodyMetrics(
            sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: 20
        )
        expectClose(BMRFormula.katchMcArdle.basalMetabolicRate(for: lean), 1752.4)
    }

    @Test("Automatic picks Katch-McArdle only when body fat was measured")
    func automaticPicksKatchOnlyWhenBodyFatWasMeasured() throws {
        #expect(BMRFormula.automatic.resolved(for: male) == .mifflinStJeor)

        let measured = try BodyMetrics(
            sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: 18
        )
        #expect(BMRFormula.automatic.resolved(for: measured) == .katchMcArdle)
    }

    @Test("Every activity level gets a maintenance number, and they increase")
    func everyActivityLevelGetsAMaintenanceNumberAndTheyIncrease() {
        let profile = profile(.maintain)

        #expect(profile.expenditureByActivity.count == ActivityLevel.allCases.count)
        #expect(profile.expenditure(at: .sedentary) < profile.expenditure(at: .light))
        #expect(profile.expenditure(at: .light) < profile.expenditure(at: .moderate))
        #expect(profile.expenditure(at: .active) < profile.expenditure(at: .athlete))

        // Selected level drives maintenance: 1780 * 1.55 = 2759
        expectClose(profile.maintenanceCalories, 2759)
    }

    @Test("Resting sits above basal and below sedentary expenditure")
    func restingSitsAboveBasal() {
        let profile = profile(.maintain)
        #expect(profile.restingMetabolicRate > profile.basalMetabolicRate)
        #expect(profile.restingMetabolicRate < profile.expenditure(at: .sedentary))
    }

    @Test("Maintenance leaves intake at expenditure")
    func maintenanceLeavesIntakeAtExpenditure() {
        let profile = profile(.maintain)
        expectClose(profile.targetCalories, profile.maintenanceCalories)
        expectClose(profile.dailyDelta, 0)
    }

    @Test("Cuts subtract and bulks add, proportionally")
    func cutsSubtractAndBulksAddProportionally() {
        let cut = profile(.moderateCut)
        let bulk = profile(.moderateBulk)

        #expect(cut.dailyDelta < 0)
        #expect(bulk.dailyDelta > 0)
        expectClose(cut.targetCalories, 2759 * 0.80)
        expectClose(bulk.targetCalories, 2759 * 1.15)
    }

    @Test("A deficit is never allowed under the safe floor")
    func deficitIsNeverAllowedUnderTheSafeFloor() throws {
        // Small, sedentary, aggressive cut: the raw target lands under 1200.
        let small = try BodyMetrics(sex: .female, age: 60, heightCM: 150, weightKG: 45)
        let profile = EnergyCalculator.profile(
            for: small, activityLevel: .sedentary, goal: .aggressiveCut
        )

        #expect(profile.wasClampedToSafeMinimum)
        #expect(profile.targetCalories == Sex.female.safeMinimumCalories)
    }

    @Test("A bulk is never clamped by the deficit floor")
    func bulkIsNeverClampedByTheDeficitFloor() {
        #expect(!profile(.aggressiveBulk, .active).wasClampedToSafeMinimum)
    }
}
