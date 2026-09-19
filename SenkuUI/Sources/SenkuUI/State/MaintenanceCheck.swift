import Foundation
import SenkuCore

/// Decides whether the app has earned the right to tell you your real
/// maintenance calories.
///
/// ## Why a gate at all
///
/// The arithmetic is trivial — intake, minus what the weight change implies —
/// and that is exactly the danger. Feed it four days and one glycogen swing and
/// it will report a maintenance figure hundreds of calories out, with the same
/// confident face it wears when the estimate is good. A number on screen gets
/// believed regardless of the small print beside it, so the honest thing is to
/// show nothing until the data can carry it.
///
/// Three conditions, all of which have to hold:
///
/// - **A fortnight of weight**, at least 8 readings across at least 14 days.
///   That is `AdaptiveMaintenance`'s own threshold, and it exists because a
///   shorter window is dominated by water rather than by tissue.
/// - **Food logged on most of those days** — 10 of the last 14. An average over
///   four days is not an estimate of what you eat, it is an estimate of what
///   you eat on days you remember to open an app, and those are not the same
///   thing.
/// - **A difference worth acting on**, at least 100 kcal. Inside that, the
///   formula and the measurement disagree by less than the noise in
///   self-reported eating, and changing a target over it would be the app
///   looking responsive while telling you nothing.
@MainActor
public enum MaintenanceCheck {
    /// Days of food logging required, out of the last fortnight.
    public static let requiredLoggedDays = 10
    public static let window = 14

    /// What the screens need to draw the card, or nil when it is too early.
    public struct Finding: Sendable {
        public let estimate: AdaptiveMaintenance
        public let loggedDays: Int

        public var measured: Double { estimate.estimatedMaintenance.rounded() }
        public var formula: Double { estimate.formulaMaintenance.rounded() }
        public var difference: Double { estimate.differenceFromFormula }

        /// "You burn about 300 more than the formula thinks."
        public var burnsMore: Bool { difference > 0 }
    }

    public static func finding(
        profile: ProfileStore.Profile?,
        weights: WeightLogStore,
        intake: IntakeStore,
        on date: Date = .now
    ) -> Finding? {
        guard let profile else { return nil }

        // Against the formula, always — comparing a measurement to a figure
        // that is itself a previous measurement would drift, agreeing with
        // itself a little more each time it was accepted.
        let formulaPlan = NutritionPlan.make(
            for: profile.metrics,
            activityLevel: profile.activityLevel,
            goal: profile.goal,
            formula: profile.formula
        )

        guard let average = intake.log.averageCalories(days: window, endingOn: date),
              average.loggedDays >= requiredLoggedDays,
              let estimate = AdaptiveMaintenance.estimate(
                  from: weights.series,
                  intakeCalories: average.calories,
                  plan: formulaPlan
              ),
              estimate.isWorthActingOn
        else { return nil }

        return Finding(estimate: estimate, loggedDays: average.loggedDays)
    }
}
