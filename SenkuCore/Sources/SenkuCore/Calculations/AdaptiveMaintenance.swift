import Foundation

/// What the scale says your maintenance calories actually are.
///
/// ## Why this exists
///
/// Every formula in this app — Mifflin-St Jeor, Katch-McArdle, Harris-Benedict
/// — estimates maintenance from a population average. Any individual can sit
/// several hundred calories either side of it, and no amount of arithmetic on
/// height and weight will find that out. Eating at a target for a fortnight and
/// weighing yourself will.
///
/// So this compares the weight change that actually happened against the one
/// the plan predicted, converts the difference into calories, and reports the
/// maintenance figure implied by the result. It is the one number in Senku
/// derived from evidence about *you* rather than from a formula, which is also
/// why it is never applied silently — see ``Advisory`` and the suggestion the
/// UI is expected to offer.
public struct AdaptiveMaintenance: Hashable, Sendable {
    /// Energy in a kilogram of body mass, and the single biggest assumption
    /// here. 7,700 kcal is the conventional figure and is already used for the
    /// forward projection in ``NutritionPlan``; using the same constant in both
    /// directions at least keeps the app consistent with itself.
    public static let caloriesPerKG = NutritionPlan.caloriesPerKGBodyMass

    /// The shortest history worth drawing a conclusion from.
    ///
    /// Two weeks and eight readings. Shorter than that and the estimate is
    /// dominated by water: a single glycogen swing can imply a maintenance
    /// figure hundreds of calories out, which is worse than no figure at all,
    /// because it looks like an answer.
    public static let minimumSpanDays: Double = 14
    public static let minimumWeighIns = 8

    /// What the user has been eating, as they reported it.
    public let intakeCalories: Double
    /// Observed change per week, from the weight series.
    public let observedWeeklyChangeKG: Double
    /// Maintenance as the formula estimated it, for comparison.
    public let formulaMaintenance: Double

    /// Maintenance implied by what happened.
    ///
    /// If you ate 2,200 and lost 0.5 kg a week, you were running about 550
    /// kcal/day short, so maintenance is about 2,750. Note the sign: losing
    /// weight means you burn *more* than you ate, so the deficit is added back,
    /// not subtracted.
    public var estimatedMaintenance: Double {
        intakeCalories - dailyDelta
    }

    /// The daily energy balance the weight change implies: negative while
    /// losing, positive while gaining.
    public var dailyDelta: Double {
        observedWeeklyChangeKG * Self.caloriesPerKG / 7
    }

    /// How far the formula was out, signed: positive when the formula
    /// underestimated what you actually burn.
    public var differenceFromFormula: Double {
        estimatedMaintenance - formulaMaintenance
    }

    public init(
        intakeCalories: Double,
        observedWeeklyChangeKG: Double,
        formulaMaintenance: Double
    ) {
        self.intakeCalories = intakeCalories
        self.observedWeeklyChangeKG = observedWeeklyChangeKG
        self.formulaMaintenance = formulaMaintenance
    }

    /// The estimate, or nil when the history cannot support one.
    ///
    /// Returning nil rather than a number with a caveat is deliberate: a figure
    /// on screen gets believed regardless of the small print beside it.
    public static func estimate(
        from series: WeightSeries,
        intakeCalories: Double,
        plan: NutritionPlan
    ) -> AdaptiveMaintenance? {
        guard series.dailyValues.count >= minimumWeighIns,
              series.spanDays >= minimumSpanDays,
              let weekly = series.weeklyChangeKG
        else { return nil }

        return AdaptiveMaintenance(
            intakeCalories: intakeCalories,
            observedWeeklyChangeKG: weekly,
            formulaMaintenance: plan.energy.maintenanceCalories
        )
    }

    /// Whether the difference is big enough to be worth acting on.
    ///
    /// A hundred calories is inside the noise of self-reported intake, and
    /// changing a plan over it would be false precision — the app would look
    /// responsive while telling you nothing.
    public var isWorthActingOn: Bool {
        abs(differenceFromFormula) >= 100
    }
}
