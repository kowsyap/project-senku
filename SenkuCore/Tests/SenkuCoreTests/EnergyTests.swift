import XCTest
@testable import SenkuCore

final class EnergyTests: XCTestCase {
    // 30yo male, 180cm, 80kg. Mifflin: 10(80) + 6.25(180) - 5(30) + 5 = 1780
    private var male: BodyMetrics!
    // 30yo female, 165cm, 60kg. Mifflin: 10(60) + 6.25(165) - 5(30) - 161 = 1320.25
    private var female: BodyMetrics!

    override func setUpWithError() throws {
        male = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 80)
        female = try BodyMetrics(sex: .female, age: 30, heightCM: 165, weightKG: 60)
    }

    func testMifflinStJeorReproducesPublishedEquation() {
        XCTAssertEqual(BMRFormula.mifflinStJeor.basalMetabolicRate(for: male), 1780, accuracy: 0.01)
        XCTAssertEqual(BMRFormula.mifflinStJeor.basalMetabolicRate(for: female), 1320.25, accuracy: 0.01)
    }

    func testKatchMcArdleWorksFromLeanMass() throws {
        // 80kg at 20% fat -> 64kg lean -> 370 + 21.6(64) = 1752.4
        let lean = try BodyMetrics(
            sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: 20
        )
        XCTAssertEqual(BMRFormula.katchMcArdle.basalMetabolicRate(for: lean), 1752.4, accuracy: 0.01)
    }

    func testAutomaticPicksKatchOnlyWhenBodyFatWasMeasured() throws {
        XCTAssertEqual(BMRFormula.automatic.resolved(for: male), .mifflinStJeor)

        let measured = try BodyMetrics(
            sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: 18
        )
        XCTAssertEqual(BMRFormula.automatic.resolved(for: measured), .katchMcArdle)
    }

    func testEveryActivityLevelGetsAMaintenanceNumberAndTheyIncrease() {
        let profile = EnergyCalculator.profile(for: male, activityLevel: .moderate, goal: .maintain)

        XCTAssertEqual(profile.expenditureByActivity.count, ActivityLevel.allCases.count)
        XCTAssertLessThan(profile.expenditure(at: .sedentary), profile.expenditure(at: .light))
        XCTAssertLessThan(profile.expenditure(at: .light), profile.expenditure(at: .moderate))
        XCTAssertLessThan(profile.expenditure(at: .active), profile.expenditure(at: .athlete))

        // Selected level drives maintenance: 1780 * 1.55 = 2759
        XCTAssertEqual(profile.maintenanceCalories, 2759, accuracy: 0.01)
    }

    func testRestingSitsAboveBasal() {
        let profile = EnergyCalculator.profile(for: male, activityLevel: .moderate, goal: .maintain)
        XCTAssertGreaterThan(profile.restingMetabolicRate, profile.basalMetabolicRate)
        XCTAssertLessThan(profile.restingMetabolicRate, profile.expenditure(at: .sedentary))
    }

    func testMaintenanceLeavesIntakeAtExpenditure() {
        let profile = EnergyCalculator.profile(for: male, activityLevel: .moderate, goal: .maintain)
        XCTAssertEqual(profile.targetCalories, profile.maintenanceCalories, accuracy: 0.01)
        XCTAssertEqual(profile.dailyDelta, 0, accuracy: 0.01)
    }

    func testCutsSubtractAndBulksAddProportionally() {
        let cut = EnergyCalculator.profile(for: male, activityLevel: .moderate, goal: .moderateCut)
        let bulk = EnergyCalculator.profile(for: male, activityLevel: .moderate, goal: .moderateBulk)

        XCTAssertLessThan(cut.dailyDelta, 0)
        XCTAssertGreaterThan(bulk.dailyDelta, 0)
        XCTAssertEqual(cut.targetCalories, 2759 * 0.80, accuracy: 0.01)
        XCTAssertEqual(bulk.targetCalories, 2759 * 1.15, accuracy: 0.01)
    }

    func testDeficitIsNeverAllowedUnderTheSafeFloor() throws {
        // Small, sedentary, aggressive cut: the raw target lands under 1200.
        let small = try BodyMetrics(sex: .female, age: 60, heightCM: 150, weightKG: 45)
        let profile = EnergyCalculator.profile(
            for: small, activityLevel: .sedentary, goal: .aggressiveCut
        )

        XCTAssertTrue(profile.wasClampedToSafeMinimum)
        XCTAssertEqual(profile.targetCalories, Sex.female.safeMinimumCalories)
    }

    func testBulkIsNeverClampedByTheDeficitFloor() {
        let profile = EnergyCalculator.profile(
            for: male, activityLevel: .active, goal: .aggressiveBulk
        )
        XCTAssertFalse(profile.wasClampedToSafeMinimum)
    }
}
