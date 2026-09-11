import Testing
@testable import SenkuCore

@Suite("Macros")
struct MacroTests {
    let male: BodyMetrics

    init() throws {
        male = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 80)
    }

    private func plan(_ goal: Goal, _ activity: ActivityLevel = .moderate) -> NutritionPlan {
        NutritionPlan.make(for: male, activityLevel: activity, goal: goal)
    }

    @Test("Macro calories reconcile with the calorie target", arguments: Goal.allCases)
    func macroCaloriesReconcileWithTheCalorieTarget(goal: Goal) {
        let macros = plan(goal).macros
        let sum = macros.proteinCalories + macros.carbCalories + macros.fatCalories
        // Rounding to whole grams and to the nearest 10 kcal moves the sum
        // slightly; anything beyond that is a real arithmetic bug.
        expectClose(sum, macros.calories, tolerance: 30)
    }

    @Test("No macro ever comes back negative", arguments: Goal.allCases)
    func noMacroEverComesBackNegative(goal: Goal) throws {
        let tiny = try BodyMetrics(sex: .female, age: 70, heightCM: 148, weightKG: 40)
        let macros = NutritionPlan.make(for: tiny, activityLevel: .sedentary, goal: goal).macros
        #expect(macros.proteinGrams >= 0)
        #expect(macros.fatGrams >= 0)
        #expect(macros.carbGrams >= 0)
    }

    @Test("Protein is highest on a cut, where it protects lean mass")
    func proteinIsHighestOnACut() {
        #expect(plan(.moderateCut).macros.proteinGrams > plan(.maintain).macros.proteinGrams)
    }

    @Test("Measured body fat shifts protein onto a lean-mass basis")
    func measuredBodyFatShiftsProteinOntoLeanMassBasis() throws {
        let measured = try BodyMetrics(
            sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: 15
        )
        let macros = NutritionPlan.make(
            for: measured, activityLevel: .moderate, goal: .moderateCut
        ).macros
        // 68 kg lean * 2.4 = 163.2 g, versus 80 * 2.2 = 176 g on a bodyweight basis.
        expectClose(macros.proteinGrams, 163, tolerance: 1)
    }

    @Test("Fat never drops below the essential minimum")
    func fatNeverDropsBelowTheEssentialMinimum() throws {
        let small = try BodyMetrics(sex: .female, age: 55, heightCM: 152, weightKG: 47)
        let macros = NutritionPlan.make(
            for: small, activityLevel: .sedentary, goal: .aggressiveCut
        ).macros
        #expect(macros.fatGrams >= (47 * MacroCalculator.essentialFatPerKG).rounded() - 1)
    }

    @Test("Protein is capped so it cannot crowd out the other macros")
    func proteinIsCappedSoItCannotCrowdOutTheOtherMacros() throws {
        let heavy = try BodyMetrics(sex: .male, age: 40, heightCM: 175, weightKG: 150)
        let macros = NutritionPlan.make(
            for: heavy, activityLevel: .sedentary, goal: .aggressiveCut
        ).macros
        #expect(macros.proteinPercentage <= 41)
    }

    @Test("Fiber tracks intake and stays inside an edible range", arguments: Goal.allCases)
    func fiberTracksIntakeAndStaysInsideAnEdibleRange(goal: Goal) {
        let fiber = plan(goal).macros.fiberGrams
        #expect(fiber >= 20)
        #expect(fiber <= 45)
    }

    @Test("Water scales with bodyweight")
    func waterScalesWithBodyweight() {
        // 80 kg * 35 ml = 2800 ml
        #expect(plan(.maintain).macros.waterML == 2800)
        #expect(plan(.maintain).macros.trainingDayExtraWaterML == 500)
    }

    @Test("Percentages sum to one hundred")
    func percentagesSumToOneHundred() {
        let macros = plan(.maintain).macros
        let total = macros.proteinPercentage + macros.carbPercentage + macros.fatPercentage
        expectClose(total, 100, tolerance: 1.5)
    }
}
