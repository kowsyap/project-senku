import Testing
@testable import SenkuCore

@Suite("Nutrition plan")
struct NutritionPlanTests {
    let male: BodyMetrics

    init() throws {
        male = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 80)
    }

    private func plan(_ goal: Goal, _ activity: ActivityLevel = .moderate) -> NutritionPlan {
        NutritionPlan.make(for: male, activityLevel: activity, goal: goal)
    }

    @Test("A cut projects loss and a bulk projects gain")
    func cutProjectsLossAndBulkProjectsGain() {
        #expect(plan(.moderateCut).projectedWeeklyChangeKG < 0)
        #expect(plan(.moderateBulk).projectedWeeklyChangeKG > 0)

        // A 20% deficit off 2759 kcal is ~552/day -> ~3864/week -> ~0.5 kg.
        expectClose(plan(.moderateCut).projectedWeeklyChangeKG, -0.50, tolerance: 0.05)
    }

    @Test("Time to target is only offered when the plan moves toward it")
    func timeToTargetIsOnlyOfferedWhenThePlanMovesTowardIt() throws {
        // Losing toward 75 kg: reachable, and roughly 10 weeks out.
        let weeks = try #require(plan(.moderateCut).projectedWeeksTo(targetWeightKG: 75))
        expectClose(weeks, 10, tolerance: 1.5)

        // Losing, but the target sits above current weight: unreachable.
        #expect(plan(.moderateCut).projectedWeeksTo(targetWeightKG: 85) == nil)

        // Maintenance never arrives anywhere.
        #expect(plan(.maintain).projectedWeeksTo(targetWeightKG: 75) == nil)
    }

    @Test("Estimated body fat is flagged so the user knows it is a guess")
    func estimatedBodyFatIsFlagged() {
        #expect(plan(.maintain).advisories.contains { $0.id == "bodyfat.estimated" })
    }

    @Test("Measured body fat drops the estimate notice")
    func measuredBodyFatDropsTheEstimateNotice() throws {
        let measured = try BodyMetrics(
            sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: 15
        )
        let plan = NutritionPlan.make(for: measured, activityLevel: .moderate, goal: .maintain)
        #expect(!plan.advisories.contains { $0.id == "bodyfat.estimated" })
    }

    @Test("Bulking at high body fat raises a caution")
    func bulkingAtHighBodyFatRaisesACaution() throws {
        let heavy = try BodyMetrics(
            sex: .male, age: 30, heightCM: 180, weightKG: 100, bodyFatPercentage: 28
        )
        let plan = NutritionPlan.make(for: heavy, activityLevel: .moderate, goal: .moderateBulk)
        #expect(plan.advisories.contains { $0.id == "bulk.highBodyFat" })
    }

    @Test("Cutting hard while already lean raises a caution")
    func cuttingHardWhileAlreadyLeanRaisesACaution() throws {
        let lean = try BodyMetrics(
            sex: .male, age: 25, heightCM: 180, weightKG: 72, bodyFatPercentage: 9
        )
        let plan = NutritionPlan.make(for: lean, activityLevel: .active, goal: .aggressiveCut)
        #expect(plan.advisories.contains { $0.id == "cut.alreadyLean" })
    }

    @Test("Clamped calories raise a warning")
    func clampedCaloriesRaiseAWarning() throws {
        let small = try BodyMetrics(sex: .female, age: 60, heightCM: 150, weightKG: 45)
        let plan = NutritionPlan.make(for: small, activityLevel: .sedentary, goal: .aggressiveCut)
        #expect(plan.advisories.contains { $0.id == "calories.clamped" && $0.severity == .warning })
    }

    @Test("A floor that lands above maintenance is called out")
    func floorAboveMaintenanceIsCalledOut() throws {
        // 45 kg and sedentary: maintenance is ~1100 kcal, under the 1200 floor,
        // so eating at the floor is actually a surplus despite the cut goal.
        let small = try BodyMetrics(sex: .female, age: 62, heightCM: 150, weightKG: 45)
        let plan = NutritionPlan.make(for: small, activityLevel: .sedentary, goal: .aggressiveCut)

        #expect(plan.energy.dailyDelta > 0)
        #expect(plan.advisories.contains { $0.id == "calories.floorAboveMaintenance" })
    }

    @Test("The floor advisory stays quiet when the clamp still leaves a deficit")
    func floorAdvisoryStaysQuietWhenTheClampStillLeavesADeficit() throws {
        // Clamped, but maintenance is comfortably above the floor, so the plan
        // remains a genuine deficit and the extra warning would be noise.
        let bigger = try BodyMetrics(sex: .female, age: 30, heightCM: 170, weightKG: 75)
        let plan = NutritionPlan.make(for: bigger, activityLevel: .sedentary, goal: .aggressiveCut)

        #expect(plan.energy.dailyDelta < 0)
        #expect(!plan.advisories.contains { $0.id == "calories.floorAboveMaintenance" })
    }

    @Test("Advisories are ordered most severe first")
    func advisoriesAreOrderedMostSevereFirst() throws {
        let minor = try BodyMetrics(sex: .female, age: 15, heightCM: 150, weightKG: 42)
        let plan = NutritionPlan.make(for: minor, activityLevel: .sedentary, goal: .aggressiveCut)

        #expect(plan.advisories.count > 1)
        let severities = plan.advisories.map(\.severity)
        #expect(severities == severities.sorted(by: >))
    }
}
