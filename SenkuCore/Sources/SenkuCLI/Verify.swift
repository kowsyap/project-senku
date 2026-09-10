import Foundation
import SenkuCore

/// A minimal assertion runner.
///
/// This duplicates a slice of the XCTest suite on purpose: XCTest cannot run
/// without Xcode installed, and the core's arithmetic is worth checking on
/// every commit regardless of what is on the machine.
struct Verifier {
    private(set) var failures: [String] = []
    private(set) var checks = 0

    mutating func expect(
        _ actual: Double,
        _ expected: Double,
        accuracy: Double = 0.01,
        _ label: String
    ) {
        checks += 1
        if abs(actual - expected) > accuracy {
            failures.append("\(label): expected \(expected), got \(actual)")
        }
    }

    mutating func expect(_ condition: Bool, _ label: String) {
        checks += 1
        if !condition {
            failures.append(label)
        }
    }
}

func runVerification() -> Int32 {
    var v = Verifier()

    let male = try! BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 80)
    let female = try! BodyMetrics(sex: .female, age: 30, heightCM: 165, weightKG: 60)
    let leanMale = try! BodyMetrics(
        sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: 20
    )

    // BMR formulas against their published equations.
    v.expect(BMRFormula.mifflinStJeor.basalMetabolicRate(for: male), 1780, "Mifflin (male)")
    v.expect(BMRFormula.mifflinStJeor.basalMetabolicRate(for: female), 1320.25, "Mifflin (female)")
    v.expect(BMRFormula.katchMcArdle.basalMetabolicRate(for: leanMale), 1752.4, "Katch-McArdle")
    v.expect(BMRFormula.automatic.resolved(for: male) == .mifflinStJeor, "Automatic without body fat")
    v.expect(BMRFormula.automatic.resolved(for: leanMale) == .katchMcArdle, "Automatic with body fat")

    // Body composition.
    v.expect(male.bmi, 24.69, accuracy: 0.01, "BMI")
    v.expect(leanMale.leanBodyMassKG, 64, "Lean mass")
    v.expect(leanMale.leanBodyMassKG + leanMale.fatMassKG, 80, "Mass split reconciles")

    let imperial = try! BodyMetrics(sex: .male, age: 30, feet: 5, inches: 10, pounds: 180)
    v.expect(imperial.heightCM, 177.8, "Imperial height")
    v.expect(imperial.weightKG, 81.647, "Imperial weight")

    // Validation rejects nonsense instead of clamping it.
    v.expect((try? BodyMetrics(sex: .male, age: 12, heightCM: 170, weightKG: 60)) == nil, "Rejects age 12")
    v.expect((try? BodyMetrics(sex: .male, age: 30, heightCM: 170, weightKG: 10)) == nil, "Rejects 10 kg")
    v.expect((try? BodyMetrics(sex: .male, age: 30, heightCM: 300, weightKG: 60)) == nil, "Rejects 300 cm")

    // Energy ladder.
    let maintain = EnergyCalculator.profile(for: male, activityLevel: .moderate, goal: .maintain)
    v.expect(maintain.maintenanceCalories, 2759, "Maintenance at moderate")
    v.expect(maintain.dailyDelta, 0, "Maintenance has no delta")
    v.expect(
        maintain.expenditure(at: .sedentary) < maintain.expenditure(at: .athlete),
        "Activity ladder increases"
    )
    v.expect(
        maintain.restingMetabolicRate > maintain.basalMetabolicRate,
        "Resting sits above basal"
    )

    let cut = EnergyCalculator.profile(for: male, activityLevel: .moderate, goal: .moderateCut)
    let bulk = EnergyCalculator.profile(for: male, activityLevel: .moderate, goal: .moderateBulk)
    v.expect(cut.targetCalories, 2759 * 0.80, "Moderate cut target")
    v.expect(bulk.targetCalories, 2759 * 1.15, "Moderate bulk target")

    // The safety floor holds, and only applies to deficits.
    let small = try! BodyMetrics(sex: .female, age: 60, heightCM: 150, weightKG: 45)
    let clamped = EnergyCalculator.profile(for: small, activityLevel: .sedentary, goal: .aggressiveCut)
    v.expect(clamped.wasClampedToSafeMinimum, "Deficit clamped to safe floor")
    v.expect(clamped.targetCalories, 1200, "Clamped to the female floor")
    v.expect(
        !EnergyCalculator.profile(for: male, activityLevel: .active, goal: .aggressiveBulk)
            .wasClampedToSafeMinimum,
        "Bulk is never clamped"
    )

    // Macros reconcile and stay inside their guard rails for every goal.
    for goal in Goal.allCases {
        let plan = NutritionPlan.make(for: male, activityLevel: .moderate, goal: goal)
        let m = plan.macros
        let sum = m.proteinCalories + m.carbCalories + m.fatCalories
        v.expect(sum, m.calories, accuracy: 30, "\(goal.rawValue) macros reconcile")
        v.expect(m.proteinGrams >= 0 && m.fatGrams >= 0 && m.carbGrams >= 0, "\(goal.rawValue) non-negative")
        v.expect(m.fiberGrams >= 20 && m.fiberGrams <= 45, "\(goal.rawValue) fiber in range")
    }

    let tiny = try! BodyMetrics(sex: .female, age: 70, heightCM: 148, weightKG: 40)
    for goal in Goal.allCases {
        let m = NutritionPlan.make(for: tiny, activityLevel: .sedentary, goal: goal).macros
        v.expect(m.proteinGrams >= 0 && m.fatGrams >= 0 && m.carbGrams >= 0, "tiny/\(goal.rawValue) non-negative")
    }

    v.expect(
        NutritionPlan.make(for: male, activityLevel: .moderate, goal: .moderateCut).macros.proteinGrams
            > NutritionPlan.make(for: male, activityLevel: .moderate, goal: .maintain).macros.proteinGrams,
        "Protein is higher on a cut"
    )

    let heavy = try! BodyMetrics(sex: .male, age: 40, heightCM: 175, weightKG: 150)
    v.expect(
        NutritionPlan.make(for: heavy, activityLevel: .sedentary, goal: .aggressiveCut)
            .macros.proteinPercentage <= 41,
        "Protein ceiling holds"
    )
    v.expect(maintain.targetCalories > 0, "Maintenance target is positive")
    v.expect(NutritionPlan.make(for: male, activityLevel: .moderate, goal: .maintain).macros.waterML, 2800, "Water target")

    // Projections point the right way and refuse impossible questions.
    let cutPlan = NutritionPlan.make(for: male, activityLevel: .moderate, goal: .moderateCut)
    v.expect(cutPlan.projectedWeeklyChangeKG, -0.50, accuracy: 0.05, "Projected weekly loss")
    v.expect(cutPlan.projectedWeeksTo(targetWeightKG: 85) == nil, "Unreachable target returns nil")
    v.expect(
        NutritionPlan.make(for: male, activityLevel: .moderate, goal: .maintain)
            .projectedWeeksTo(targetWeightKG: 75) == nil,
        "Maintenance never reaches a target"
    )

    // Advisories fire where they should.
    v.expect(
        NutritionPlan.make(for: male, activityLevel: .moderate, goal: .maintain)
            .advisories.contains { $0.id == "bodyfat.estimated" },
        "Estimated body fat is flagged"
    )
    v.expect(
        !NutritionPlan.make(for: leanMale, activityLevel: .moderate, goal: .maintain)
            .advisories.contains { $0.id == "bodyfat.estimated" },
        "Measured body fat is not flagged"
    )
    // Clamping can invert a cut into a surplus; that must be surfaced.
    let floored = try! BodyMetrics(sex: .female, age: 62, heightCM: 150, weightKG: 45)
    let flooredPlan = NutritionPlan.make(for: floored, activityLevel: .sedentary, goal: .aggressiveCut)
    v.expect(flooredPlan.energy.dailyDelta > 0, "Floor above maintenance yields a surplus")
    v.expect(
        flooredPlan.advisories.contains { $0.id == "calories.floorAboveMaintenance" },
        "Floor above maintenance is flagged"
    )
    let deficitStillHolds = try! BodyMetrics(sex: .female, age: 30, heightCM: 170, weightKG: 75)
    v.expect(
        !NutritionPlan.make(for: deficitStillHolds, activityLevel: .sedentary, goal: .aggressiveCut)
            .advisories.contains { $0.id == "calories.floorAboveMaintenance" },
        "Floor advisory stays quiet on a real deficit"
    )

    let minor = try! BodyMetrics(sex: .female, age: 15, heightCM: 150, weightKG: 42)
    let minorPlan = NutritionPlan.make(for: minor, activityLevel: .sedentary, goal: .aggressiveCut)
    v.expect(minorPlan.advisories.contains { $0.id == "age.minor" }, "Minors are warned")
    v.expect(
        minorPlan.advisories.map(\.severity) == minorPlan.advisories.map(\.severity).sorted(by: >),
        "Advisories sorted by severity"
    )

    if v.failures.isEmpty {
        print("✓ \(v.checks) checks passed")
        return 0
    }
    print("✗ \(v.failures.count) of \(v.checks) checks failed\n")
    for failure in v.failures {
        print("  • \(failure)")
    }
    return 1
}
