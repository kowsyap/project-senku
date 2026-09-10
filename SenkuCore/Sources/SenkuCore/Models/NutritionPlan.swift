import Foundation

/// Everything Senku knows about one person's targets, in a single value.
///
/// This is the type the UI binds to. Building it is pure and synchronous, so a
/// view can rebuild it on every keystroke without any concurrency machinery.
public struct NutritionPlan: Hashable, Sendable {
    public let metrics: BodyMetrics
    public let energy: EnergyProfile
    public let macros: MacroTargets
    public let advisories: [Advisory]

    /// Energy in one kilogram of body mass, used for rate projections.
    /// Roughly 7,700 kcal — the figure is an approximation, and real change
    /// includes water and glycogen, so projections are directional only.
    public static let caloriesPerKGBodyMass: Double = 7700

    public static func make(
        for metrics: BodyMetrics,
        activityLevel: ActivityLevel,
        goal: Goal,
        formula: BMRFormula = .automatic
    ) -> NutritionPlan {
        let energy = EnergyCalculator.profile(
            for: metrics,
            activityLevel: activityLevel,
            goal: goal,
            formula: formula
        )
        return NutritionPlan(
            metrics: metrics,
            energy: energy,
            macros: MacroCalculator.targets(for: metrics, energy: energy),
            advisories: advisories(for: metrics, energy: energy)
        )
    }

    /// Expected weekly weight change in kilograms. Negative on a cut.
    public var projectedWeeklyChangeKG: Double {
        energy.dailyDelta * 7 / Self.caloriesPerKGBodyMass
    }

    /// Weeks to reach `targetWeightKG` at the current rate, or `nil` when the
    /// plan moves away from the target or holds weight steady.
    public func projectedWeeksTo(targetWeightKG: Double) -> Double? {
        let change = projectedWeeklyChangeKG
        guard abs(change) > 0.001 else { return nil }
        let distance = targetWeightKG - metrics.weightKG
        guard distance.sign == change.sign, abs(distance) > 0.001 else { return nil }
        return distance / change
    }

    private static func advisories(
        for metrics: BodyMetrics,
        energy: EnergyProfile
    ) -> [Advisory] {
        var notes: [Advisory] = []

        if energy.wasClampedToSafeMinimum {
            notes.append(Advisory(
                id: "calories.clamped",
                severity: .warning,
                message: """
                This goal would put you under \(Int(metrics.sex.safeMinimumCalories)) calories a \
                day. Senku raised your target to that floor. Going lower is a decision to make \
                with a doctor, not an app.
                """
            ))
        }

        // Clamping can invert the direction of the plan: for a small, sedentary
        // person the safe floor can sit above maintenance, so a "cut" becomes a
        // slight surplus. Saying so is better than letting the user work it out
        // from a deficit that reads as a positive number.
        if energy.wasClampedToSafeMinimum, energy.dailyDelta > 0 {
            notes.append(Advisory(
                id: "calories.floorAboveMaintenance",
                severity: .warning,
                message: """
                At your size the safe minimum is actually above what you burn in a day, so this \
                target will hold your weight or add a little. Losing weight from here means \
                moving more rather than eating less — and is worth a conversation with a doctor.
                """
            ))
        }

        if metrics.bodyFatPercentage == nil {
            notes.append(Advisory(
                id: "bodyfat.estimated",
                severity: .info,
                message: """
                Body fat is estimated from your BMI, so it can be off by several points. Add a \
                measured number to sharpen your protein target.
                """
            ))
        }

        if metrics.age < 18 {
            notes.append(Advisory(
                id: "age.minor",
                severity: .warning,
                message: """
                These formulas are built for adults. If you are still growing, talk to a doctor \
                before eating to a deficit.
                """
            ))
        }

        let bodyFat = metrics.effectiveBodyFatPercentage
        let leanThreshold: Double = metrics.sex == .male ? 12 : 20
        let highThreshold: Double = metrics.sex == .male ? 20 : 30

        if energy.goal == .aggressiveCut, bodyFat < leanThreshold {
            notes.append(Advisory(
                id: "cut.alreadyLean",
                severity: .caution,
                message: """
                You are already lean. An aggressive cut from here costs muscle and recovery — a \
                mild cut will get you there in better shape.
                """
            ))
        }

        if energy.goal.isBulk, bodyFat > highThreshold {
            notes.append(Advisory(
                id: "bulk.highBodyFat",
                severity: .caution,
                message: """
                At your current body fat, a bulk will add proportionally more fat. A cut or a \
                maintenance recomp first usually pays off.
                """
            ))
        }

        if metrics.bmi < 18.5 {
            notes.append(Advisory(
                id: "bmi.low",
                severity: .caution,
                message: "Your BMI is below the healthy range. Losing more weight is not the goal to chase."
            ))
        }

        return notes.sorted { $0.severity > $1.severity }
    }
}
