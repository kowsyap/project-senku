import XCTest
@testable import SenkuCore

final class MacroTests: XCTestCase {
    private var male: BodyMetrics!

    override func setUpWithError() throws {
        male = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 80)
    }

    private func plan(_ goal: Goal, _ activity: ActivityLevel = .moderate) -> NutritionPlan {
        NutritionPlan.make(for: male, activityLevel: activity, goal: goal)
    }

    func testMacroCaloriesReconcileWithTheCalorieTarget() {
        for goal in Goal.allCases {
            let macros = plan(goal).macros
            let sum = macros.proteinCalories + macros.carbCalories + macros.fatCalories
            // Rounding to whole grams and to the nearest 10 kcal moves the sum
            // slightly; anything beyond that is a real arithmetic bug.
            XCTAssertEqual(sum, macros.calories, accuracy: 30, "\(goal) failed to reconcile")
        }
    }

    func testNoMacroEverComesBackNegative() throws {
        let tiny = try BodyMetrics(sex: .female, age: 70, heightCM: 148, weightKG: 40)
        for goal in Goal.allCases {
            let macros = NutritionPlan.make(for: tiny, activityLevel: .sedentary, goal: goal).macros
            XCTAssertGreaterThanOrEqual(macros.proteinGrams, 0, "\(goal)")
            XCTAssertGreaterThanOrEqual(macros.fatGrams, 0, "\(goal)")
            XCTAssertGreaterThanOrEqual(macros.carbGrams, 0, "\(goal)")
        }
    }

    func testProteinIsHighestOnACutWhereItProtectsLeanMass() {
        XCTAssertGreaterThan(plan(.moderateCut).macros.proteinGrams, plan(.maintain).macros.proteinGrams)
    }

    func testMeasuredBodyFatShiftsProteinOntoLeanMassBasis() throws {
        let measured = try BodyMetrics(
            sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: 15
        )
        let macros = NutritionPlan.make(
            for: measured, activityLevel: .moderate, goal: .moderateCut
        ).macros
        // 68 kg lean * 2.4 = 163.2 g, versus 80 * 2.2 = 176 g on a bodyweight basis.
        XCTAssertEqual(macros.proteinGrams, 163, accuracy: 1)
    }

    func testFatNeverDropsBelowTheEssentialMinimum() throws {
        let small = try BodyMetrics(sex: .female, age: 55, heightCM: 152, weightKG: 47)
        let macros = NutritionPlan.make(
            for: small, activityLevel: .sedentary, goal: .aggressiveCut
        ).macros
        XCTAssertGreaterThanOrEqual(macros.fatGrams, (47 * MacroCalculator.essentialFatPerKG).rounded() - 1)
    }

    func testProteinIsCappedSoItCannotCrowdOutTheOtherMacros() throws {
        let heavy = try BodyMetrics(sex: .male, age: 40, heightCM: 175, weightKG: 150)
        let macros = NutritionPlan.make(
            for: heavy, activityLevel: .sedentary, goal: .aggressiveCut
        ).macros
        XCTAssertLessThanOrEqual(macros.proteinPercentage, 41)
    }

    func testFiberTracksIntakeAndStaysInsideAnEdibleRange() {
        for goal in Goal.allCases {
            let fiber = plan(goal).macros.fiberGrams
            XCTAssertGreaterThanOrEqual(fiber, 20, "\(goal)")
            XCTAssertLessThanOrEqual(fiber, 45, "\(goal)")
        }
    }

    func testWaterScalesWithBodyweight() {
        // 80 kg * 35 ml = 2800 ml
        XCTAssertEqual(plan(.maintain).macros.waterML, 2800)
        XCTAssertEqual(plan(.maintain).macros.trainingDayExtraWaterML, 500)
    }

    func testPercentagesSumToOneHundred() {
        let macros = plan(.maintain).macros
        let total = macros.proteinPercentage + macros.carbPercentage + macros.fatPercentage
        XCTAssertEqual(total, 100, accuracy: 1.5)
    }
}
