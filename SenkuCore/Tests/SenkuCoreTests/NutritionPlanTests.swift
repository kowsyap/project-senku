import XCTest
@testable import SenkuCore

final class NutritionPlanTests: XCTestCase {
    private var male: BodyMetrics!

    override func setUpWithError() throws {
        male = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 80)
    }

    func testCutProjectsLossAndBulkProjectsGain() {
        let cut = NutritionPlan.make(for: male, activityLevel: .moderate, goal: .moderateCut)
        let bulk = NutritionPlan.make(for: male, activityLevel: .moderate, goal: .moderateBulk)

        XCTAssertLessThan(cut.projectedWeeklyChangeKG, 0)
        XCTAssertGreaterThan(bulk.projectedWeeklyChangeKG, 0)

        // A 20% deficit off 2759 kcal is ~552/day -> ~3864/week -> ~0.5 kg.
        XCTAssertEqual(cut.projectedWeeklyChangeKG, -0.50, accuracy: 0.05)
    }

    func testTimeToTargetIsOnlyOfferedWhenThePlanMovesTowardIt() throws {
        let cut = NutritionPlan.make(for: male, activityLevel: .moderate, goal: .moderateCut)
        let maintain = NutritionPlan.make(for: male, activityLevel: .moderate, goal: .maintain)

        // Losing toward 75 kg: reachable, and roughly 10 weeks out.
        let weeks = try XCTUnwrap(cut.projectedWeeksTo(targetWeightKG: 75))
        XCTAssertEqual(weeks, 10, accuracy: 1.5)

        // Losing, but the target sits above current weight: unreachable.
        XCTAssertNil(cut.projectedWeeksTo(targetWeightKG: 85))

        // Maintenance never arrives anywhere.
        XCTAssertNil(maintain.projectedWeeksTo(targetWeightKG: 75))
    }

    func testEstimatedBodyFatIsFlaggedSoTheUserKnowsItIsAGuess() {
        let plan = NutritionPlan.make(for: male, activityLevel: .moderate, goal: .maintain)
        XCTAssertTrue(plan.advisories.contains { $0.id == "bodyfat.estimated" })
    }

    func testMeasuredBodyFatDropsTheEstimateNotice() throws {
        let measured = try BodyMetrics(
            sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: 15
        )
        let plan = NutritionPlan.make(for: measured, activityLevel: .moderate, goal: .maintain)
        XCTAssertFalse(plan.advisories.contains { $0.id == "bodyfat.estimated" })
    }

    func testBulkingAtHighBodyFatRaisesACaution() throws {
        let heavy = try BodyMetrics(
            sex: .male, age: 30, heightCM: 180, weightKG: 100, bodyFatPercentage: 28
        )
        let plan = NutritionPlan.make(for: heavy, activityLevel: .moderate, goal: .moderateBulk)
        XCTAssertTrue(plan.advisories.contains { $0.id == "bulk.highBodyFat" })
    }

    func testCuttingHardWhileAlreadyLeanRaisesACaution() throws {
        let lean = try BodyMetrics(
            sex: .male, age: 25, heightCM: 180, weightKG: 72, bodyFatPercentage: 9
        )
        let plan = NutritionPlan.make(for: lean, activityLevel: .active, goal: .aggressiveCut)
        XCTAssertTrue(plan.advisories.contains { $0.id == "cut.alreadyLean" })
    }

    func testClampedCaloriesRaiseAWarning() throws {
        let small = try BodyMetrics(sex: .female, age: 60, heightCM: 150, weightKG: 45)
        let plan = NutritionPlan.make(for: small, activityLevel: .sedentary, goal: .aggressiveCut)
        XCTAssertTrue(plan.advisories.contains { $0.id == "calories.clamped" && $0.severity == .warning })
    }

    func testAdvisoriesAreOrderedMostSevereFirst() throws {
        let minor = try BodyMetrics(sex: .female, age: 15, heightCM: 150, weightKG: 42)
        let plan = NutritionPlan.make(for: minor, activityLevel: .sedentary, goal: .aggressiveCut)

        XCTAssertGreaterThan(plan.advisories.count, 1)
        let severities = plan.advisories.map(\.severity)
        XCTAssertEqual(severities, severities.sorted(by: >))
    }
}
