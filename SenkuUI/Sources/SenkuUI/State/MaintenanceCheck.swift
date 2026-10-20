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
/// ## Fourteen complete days in a row
///
/// A day counts when it has both a weigh-in and food logged. Fourteen of them
/// in a row, and the check runs; a day missing either sends the count back to
/// nothing. Calories for a past day can still be filled in from the streak
/// screen, and that mends the day. A weight cannot — a weigh-in typed in after
/// the fact is a guess, and a guess bends the trend — so the weigh-in sheet
/// only takes today.
///
/// Every day rather than most of them because the window is short. Over two
/// weeks, a weight trend through fourteen daily readings is steady; through
/// eight it is at the mercy of which eight. And today is never one of the
/// fourteen: at ten in the morning it is a day of breakfast, and counting it
/// drags the average down.
///
/// ## A count, and a fresh one after every answer
///
/// The count begins on a day stored in ``MaintenanceCycleStore`` — the day the
/// feature first ran, then the day of each decision. Accepting or dismissing a
/// suggestion starts it again, so the next one rests on fourteen days the last
/// one never saw: if it agrees, that is confirmation rather than an echo of the
/// same data. Fourteen days that come out within 100 kcal of the plan say
/// nothing and start the count again on their own.
///
/// ## Waiting on a decision
///
/// Until you answer, the suggestion follows the latest fourteen days: each new
/// complete day moves the window on by one and the figure is worked out again,
/// so a suggestion left for three days stands on days four to seventeen. A day
/// missing either still breaks the run, and the suggestion goes with it.
///
/// ## Against the figure in use
///
/// The comparison is with the maintenance the plan is using now — the
/// formula's, or a measured figure accepted at an earlier check. Against the
/// formula, an accepted figure would be offered back every fortnight.
@MainActor
public enum MaintenanceCheck {
    /// Complete days in a row before a suggestion.
    public static let requiredDays = 14

    /// What the screens need to draw a suggestion.
    public struct Finding: Sendable {
        public let estimate: AdaptiveMaintenance
        /// The first and last of the fourteen days.
        public let firstDay: Date
        public let lastDay: Date

        public var measured: Double { estimate.estimatedMaintenance.rounded() }
        /// What the plan is using now.
        public var current: Double { estimate.baselineMaintenance.rounded() }
        public var difference: Double { estimate.differenceFromBaseline }

        /// "You burn about 300 more than your plan assumes."
        public var burnsMore: Bool { difference > 0 }
    }

    public enum Status: Sendable {
        /// Still counting: finished days in a row that had both, and whether
        /// today has each so far.
        case counting(days: Int, weighedToday: Bool, ateToday: Bool)
        /// Fourteen days or more in a row, and the latest fourteen disagree
        /// with the plan. `days` is the whole run.
        case ready(Finding, days: Int)
    }

    public struct Result: Sendable {
        public let status: Status
        /// The first day of the count this status belongs to. Later than the
        /// stored one when a fortnight came out on track and the count started
        /// again — worth saving, so a later change to the profile cannot
        /// reopen a fortnight that was already settled.
        public let cycleStart: Date

        public var isReady: Bool {
            if case .ready = status { true } else { false }
        }
    }

    public static func check(
        profile: ProfileStore.Profile?,
        weights: WeightLogStore,
        intake: IntakeStore,
        since start: Date,
        on date: Date = .now
    ) -> Result? {
        guard let profile else { return nil }

        let calendar = Calendar.logging
        let today = calendar.startOfDay(for: date)
        let weighed = Set(weights.weighIns.map { calendar.startOfDay(for: $0.date) })
        let ate = Set(intake.entries.map { calendar.startOfDay(for: $0.date) })

        var cycleStart = min(calendar.startOfDay(for: start), today)
        var run = 0
        var latest: Finding?
        var day = cycleStart

        while day < today {
            if weighed.contains(day) && ate.contains(day) {
                run += 1
            } else {
                run = 0
                latest = nil
            }

            if run >= requiredDays {
                latest = finding(
                    endingOn: day, profile: profile, weights: weights, intake: intake, calendar: calendar
                )
                if latest == nil {
                    // On track: nothing to say, and the count starts again.
                    run = 0
                    cycleStart = calendar.date(byAdding: .day, value: 1, to: day) ?? today
                }
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        if let latest {
            return Result(status: .ready(latest, days: run), cycleStart: cycleStart)
        }

        return Result(
            status: .counting(
                days: run,
                weighedToday: weighed.contains(today),
                ateToday: ate.contains(today)
            ),
            cycleStart: cycleStart
        )
    }

    /// The fourteen days ending `lastDay`, or nil when they agree with the
    /// plan closely enough that there is nothing to say.
    private static func finding(
        endingOn lastDay: Date,
        profile: ProfileStore.Profile,
        weights: WeightLogStore,
        intake: IntakeStore,
        calendar: Calendar
    ) -> Finding? {
        guard let firstDay = calendar.date(byAdding: .day, value: -(requiredDays - 1), to: lastDay),
              let dayAfter = calendar.date(byAdding: .day, value: 1, to: lastDay)
        else { return nil }

        let series = WeightSeries(
            weights.weighIns.filter { $0.date >= firstDay && $0.date < dayAfter },
            calendar: calendar
        )

        guard let average = intake.log.averageCalories(days: requiredDays, endingOn: lastDay),
              let estimate = AdaptiveMaintenance.estimate(
                  from: series,
                  intakeCalories: average.calories,
                  plan: profile.plan
              ),
              estimate.isWorthActingOn
        else { return nil }

        return Finding(estimate: estimate, firstDay: firstDay, lastDay: lastDay)
    }
}
