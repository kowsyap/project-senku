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
/// ## One window for both
///
/// Food and weight are read over the same days: the last three weeks, ending
/// yesterday. The weight trend once came from every weigh-in ever logged while
/// the food came from the last fortnight — so three months of dieting followed
/// by two weeks at maintenance read as two weeks of eating that somehow still
/// lost weight, and offered a maintenance figure far too high. And today is
/// left out because it is not over: at ten in the morning it is a day of
/// breakfast, and counting it drags the average down.
///
/// Three weeks rather than two: long enough that one salty meal or a day of
/// water does not swing the trend, short enough to follow a change of diet
/// within the month.
///
/// Three conditions, all of which have to hold:
///
/// - **Weight across the window**, at least 8 readings spanning at least 14
///   days of it. That is `AdaptiveMaintenance`'s own threshold, and it exists
///   because a shorter stretch is dominated by water rather than by tissue.
/// - **Food logged on most of those days** — 15 of the 21. An average over
///   four days is not an estimate of what you eat, it is an estimate of what
///   you eat on days you remember to open an app, and those are not the same
///   thing.
/// - **A difference worth acting on**, at least 100 kcal. Inside that, the
///   formula and the measurement disagree by less than the noise in
///   self-reported eating, and changing a target over it would be the app
///   looking responsive while telling you nothing.
@MainActor
public enum MaintenanceCheck {
    /// The days measured: this many full days, ending yesterday.
    public static let window = 21
    /// Days of food logging required within them — about seventy per cent.
    public static let requiredLoggedDays = 15

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

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let firstDay = calendar.date(byAdding: .day, value: -window, to: today)
        else { return nil }
        // Weigh-ins from the same days the food is averaged over, and none
        // from today.
        let recent = WeightSeries(weights.weighIns.filter { $0.date >= firstDay && $0.date < today })

        guard let average = intake.log.averageCalories(days: window, endingOn: yesterday),
              average.loggedDays >= requiredLoggedDays,
              let estimate = AdaptiveMaintenance.estimate(
                  from: recent,
                  intakeCalories: average.calories,
                  plan: formulaPlan
              ),
              estimate.isWorthActingOn
        else { return nil }

        return Finding(estimate: estimate, loggedDays: average.loggedDays)
    }
}
