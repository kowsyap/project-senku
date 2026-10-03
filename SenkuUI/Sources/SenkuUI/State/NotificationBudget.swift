import Foundation

/// Every pending notification the app can hold, shared out in one place.
///
/// ## The 64
///
/// iOS keeps at most 64 *pending* requests per app. Past that it keeps the
/// soonest-firing 64 and silently drops the rest — no error, nothing to catch,
/// and the symptom is "reminders stopped working in March".
///
/// So each feature gets an allocation here, every scheduler takes its ceiling
/// from here rather than from a number of its own, and a test adds them up.
/// The doc comment that used to hold this arithmetic had already gone stale by
/// the time it was checked — it said fourteen when the app was using sixteen —
/// which is the argument for making it code that fails instead of prose that
/// drifts.
///
/// Counted in **requests**, never in items: a due date reminded three days
/// before *and* on the day costs two.
public enum NotificationBudget {
    public static let limit = 64

    public enum Feature: CaseIterable, Sendable {
        /// One repeating trigger per slot through the day.
        case water
        /// The finished alert and its sweep.
        case rest
        case weighIn
        case creatine
        /// Bills, renewals, deadlines — the one that can grow.
        case dueDates
    }

    public static func allocation(_ feature: Feature) -> Int {
        switch feature {
        case .water: 12
        case .rest: 2
        case .weighIn: 1
        case .creatine: 1
        case .dueDates: 42
        }
    }

    /// Held back on purpose: a margin against miscounting, which is the
    /// mistake this type exists because of — not room for a feature nobody has
    /// planned.
    public static let reserve = 6

    public static var allocated: Int {
        Feature.allCases.reduce(0) { $0 + allocation($1) }
    }
}
