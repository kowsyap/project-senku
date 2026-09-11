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


    // MARK: Rest timer
    //
    // The property that matters most is that nothing decays while the app is
    // away, so every check below jumps `now` forward by minutes at a time
    // rather than waiting.

    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    var timer = RestTimer(preset: .ninetySeconds)
    v.expect(timer.duration, 90, "Preset duration")
    v.expect(timer.isIdle, "New timer is idle")
    v.expect(timer.remaining(at: t0), 90, "Idle timer reads full")
    v.expect(timer.progress(at: t0), 0, "Idle progress is zero")
    v.expect(timer.endsAt == nil, "Idle timer has no deadline")

    timer.start(at: t0)
    v.expect(timer.isRunning, "Started timer runs")
    v.expect(timer.remaining(at: at(30)), 60, "Remaining after 30s")
    v.expect(timer.progress(at: at(45)), 0.5, "Halfway progress")
    v.expect(timer.endsAt == at(90), "Deadline is start plus duration")

    // Suspension: the clock jumps far past the deadline while nothing runs.
    v.expect(timer.remaining(at: at(600)), 0, "Remaining clamps at zero")
    v.expect(timer.progress(at: at(600)), 1, "Progress clamps at one")
    v.expect(timer.hasFinished(at: at(600)), "Elapsed timer reads finished")
    v.expect(!timer.hasFinished(at: at(89)), "Not finished a second early")

    // refresh reports the crossing exactly once, stamped at the deadline.
    var crossing = timer
    v.expect(crossing.refresh(at: at(89)) == false, "No crossing before the deadline")
    v.expect(crossing.refresh(at: at(600)) == true, "Crossing reported once")
    v.expect(crossing.refresh(at: at(601)) == false, "Crossing not reported twice")
    if case .finished(let stamp) = crossing.phase {
        v.expect(stamp == at(90), "Finish stamped at the deadline, not the late call")
    } else {
        v.expect(false, "Refreshed timer is finished")
    }
    v.expect(crossing.overrun(at: at(150)), 60, "Overrun measured from the deadline")

    // Pause banks the remainder, and a long gap does not consume it.
    var held = RestTimer(preset: .twoMinutes)
    held.start(at: t0)
    held.pause(at: at(30))
    v.expect(held.isPaused, "Paused timer is paused")
    v.expect(held.endsAt == nil, "Paused timer has no deadline")
    v.expect(held.remaining(at: at(30)), 90, "Paused timer banks the remainder")
    v.expect(held.remaining(at: at(3000)), 90, "Paused time does not decay")
    held.resume(at: at(3000))
    v.expect(held.remaining(at: at(3000)), 90, "Resume restores the remainder")
    v.expect(held.endsAt == at(3090), "Resume rebuilds the deadline from now")
    v.expect(held.duration, 120, "Pausing leaves duration alone")

    // Pausing after the deadline finishes rather than parking at zero.
    var late = RestTimer(preset: .sixtySeconds)
    late.start(at: t0)
    late.pause(at: at(200))
    v.expect(!late.isPaused, "Pausing an elapsed timer does not park it")
    v.expect(late.hasFinished(at: at(200)), "Pausing an elapsed timer finishes it")

    // toggle drives the one button the UI has.
    var toggled = RestTimer(preset: .sixtySeconds)
    toggled.toggle(at: t0)
    v.expect(toggled.isRunning, "Toggle starts an idle timer")
    toggled.toggle(at: at(10))
    v.expect(toggled.isPaused, "Toggle pauses a running timer")
    toggled.toggle(at: at(20))
    v.expect(toggled.isRunning, "Toggle resumes a paused timer")

    // Extending.
    var extended = RestTimer(preset: .sixtySeconds)
    extended.start(at: t0)
    extended.extend(by: 30, at: at(10))
    v.expect(extended.remaining(at: at(10)), 80, "Extend adds to what is left")
    v.expect(extended.duration, 90, "Extend grows the duration too")
    extended.extend(by: -1000, at: at(10))
    v.expect(extended.remaining(at: at(10)), RestTimer.allowedDuration.lowerBound, "Extend clamps at the floor")

    var revived = RestTimer(preset: .sixtySeconds)
    revived.start(at: t0)
    revived.refresh(at: at(60))
    revived.extend(by: 30, at: at(60))
    v.expect(revived.isRunning, "Extending a finished timer restarts it")
    v.expect(revived.remaining(at: at(60)), 30, "Restarted for the added amount")

    // Changing the duration mid-run restarts rather than keeping a stale deadline.
    var swapped = RestTimer(preset: .fiveMinutes)
    swapped.start(at: t0)
    try! swapped.setDuration(60, at: at(10))
    v.expect(swapped.remaining(at: at(10)), 60, "New duration takes effect immediately")
    v.expect(swapped.endsAt == at(70), "Deadline rebuilt from the new duration")

    // Validation at the boundary.
    v.expect((try? RestTimer(duration: 0)) == nil, "Rejects a zero rest")
    v.expect((try? RestTimer(duration: 4)) == nil, "Rejects below the floor")
    v.expect((try? RestTimer(duration: 3601)) == nil, "Rejects above the ceiling")
    v.expect((try? RestTimer(duration: 5)) != nil, "Accepts the floor")
    v.expect((try? RestTimer(duration: 3600)) != nil, "Accepts the ceiling")

    for preset in RestPreset.allCases {
        v.expect(
            RestTimer.allowedDuration.contains(preset.duration),
            "\(preset.rawValue) is a legal duration"
        )
        v.expect(RestPreset.matching(preset.duration) == preset, "\(preset.rawValue) round trips")
    }
    v.expect(RestPreset.matching(137) == nil, "A custom duration matches no preset")

    // A timer survives being written out and read back, which is what a Live
    // Activity restore and a relaunch mid-rest both amount to.
    var encoded = RestTimer(preset: .threeMinutes)
    encoded.start(at: t0)
    let restored = try! JSONDecoder().decode(
        RestTimer.self, from: try! JSONEncoder().encode(encoded)
    )
    v.expect(restored == encoded, "Timer round trips through Codable")
    v.expect(restored.remaining(at: at(60)), 120, "Restored timer keeps its deadline")

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
