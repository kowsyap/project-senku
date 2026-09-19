import Foundation

/// The full energy picture for one person: what they burn at rest, at each
/// activity level, and what they should eat to hit their goal.
public struct EnergyProfile: Hashable, Sendable {
    /// Energy burned in a day at complete rest. The floor of the whole model.
    public let basalMetabolicRate: Double

    /// Resting metabolic rate — BMR plus the small cost of being awake.
    public let restingMetabolicRate: Double

    /// Maintenance calories at every activity level, so the user can see how
    /// much a change in training actually moves the number.
    public let expenditureByActivity: [ActivityLevel: Double]

    /// Maintenance at the activity level the user selected.
    public let maintenanceCalories: Double

    /// What to eat for the selected goal, after safety clamping.
    public let targetCalories: Double

    /// Daily surplus or deficit against maintenance. Negative on a cut.
    public let dailyDelta: Double

    public let formulaUsed: BMRFormula
    public let activityLevel: ActivityLevel
    public let goal: Goal

    /// True when the goal's target fell below the safe floor and was raised.
    public let wasClampedToSafeMinimum: Bool

    /// True when `maintenanceCalories` came from what the scale did rather than
    /// from a formula — see ``AdaptiveMaintenance``. Worth carrying so the
    /// screens can say which kind of number they are showing: one is an
    /// estimate about people like you, the other is a measurement of you.
    public var isMaintenanceMeasured = false

    public func expenditure(at level: ActivityLevel) -> Double {
        expenditureByActivity[level] ?? basalMetabolicRate * level.multiplier
    }
}

public enum EnergyCalculator {
    /// Awake-but-idle costs slightly more than true basal metabolism.
    static let restingMultiplier = 1.1

    /// - Parameter measuredMaintenance: A maintenance figure observed from
    ///   intake against weight change, which replaces the formula's when given.
    ///   The activity table is still computed, because it is what makes the
    ///   measured number legible — "you burn like someone a level above what
    ///   you picked" is the useful reading of it.
    public static func profile(
        for metrics: BodyMetrics,
        activityLevel: ActivityLevel,
        goal: Goal,
        formula: BMRFormula = .automatic,
        measuredMaintenance: Double? = nil
    ) -> EnergyProfile {
        let resolvedFormula = formula.resolved(for: metrics)
        let bmr = resolvedFormula.basalMetabolicRate(for: metrics)

        let expenditure = Dictionary(
            uniqueKeysWithValues: ActivityLevel.allCases.map {
                ($0, bmr * $0.multiplier)
            }
        )

        let maintenance = measuredMaintenance ?? bmr * activityLevel.multiplier
        let rawTarget = maintenance * goal.calorieMultiplier

        // A deficit must never push intake under the medically safe floor.
        // Bulks are left alone: eating more is not the risk being guarded here.
        let floor = metrics.sex.safeMinimumCalories
        let clamped = goal.isCut && rawTarget < floor
        let target = clamped ? floor : rawTarget

        return EnergyProfile(
            basalMetabolicRate: bmr,
            restingMetabolicRate: bmr * restingMultiplier,
            expenditureByActivity: expenditure,
            maintenanceCalories: maintenance,
            targetCalories: target,
            dailyDelta: target - maintenance,
            formulaUsed: resolvedFormula,
            activityLevel: activityLevel,
            goal: goal,
            wasClampedToSafeMinimum: clamped,
            isMaintenanceMeasured: measuredMaintenance != nil
        )
    }
}
