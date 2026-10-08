import Foundation

/// Active energy for a lifting session, estimated from its length and the
/// lifter's weight.
///
/// ## Why time, not the weight lifted
///
/// Moving the bar itself is a small part of a session's cost — a few dozen
/// kilocalories of mechanical work for a full workout. Most of it is the raised
/// heart rate and breathing, the bracing, and the recovery between sets, which
/// scale with how long you were at it and how heavy you are, not with what was
/// on the bar. So this is the MET method: an intensity figure from the
/// literature, times body weight, times hours.
///
/// It is an estimate and is only ever shown as one, with its working beside it.
/// A heart-rate measurement is the only thing that can tell a hard hour from an
/// easy one; this cannot.
public enum WorkoutEnergy {
    /// How hard the session was, as the Compendium of Physical Activities
    /// (Ainsworth et al., 2011) grades resistance training.
    public enum Effort: String, CaseIterable, Codable, Sendable, Identifiable {
        /// "Resistance (weight) training, multiple exercises, 8–15 repetitions
        /// at varied resistance."
        case light
        /// "Resistance training — power lifting or body building, vigorous
        /// effort."
        case vigorous

        public var id: String { rawValue }

        public var met: Double {
            switch self {
            case .light: 3.5
            case .vigorous: 6.0
            }
        }

        public var title: String {
            switch self {
            case .light: "Light"
            case .vigorous: "Vigorous"
            }
        }
    }

    /// Shorter than this and the session's clock is almost certainly not the
    /// session — started late, or everything logged at the end.
    public static let shortest: TimeInterval = 5 * 60

    /// Longer than this and the finish was probably tapped well after leaving.
    public static let longest: TimeInterval = 3 * 60 * 60

    public enum DurationCheck: Equatable, Sendable {
        case plausible
        /// Too short to be the session: ask how long it really was.
        case tooShort
        /// Possible, but worth a second look before it goes anywhere.
        case unusuallyLong
    }

    /// What a session's duration was measured from.
    public enum DurationBasis: Equatable, Sendable {
        /// First thing logged to last: the time actually spent training.
        case loggedSpan
        /// The session's own clock, start to finish.
        case startToFinish
    }

    /// When the training happened, and how long it lasted.
    ///
    /// The first logged set to the last, by preference: it leaves out the
    /// minutes before the first set and after the last that the session's
    /// clock counts. But it is only as good as the logging, and sets logged
    /// together at the end give a span of seconds — so under ``shortest`` it
    /// falls back to start to finish, and says which it used.
    public static func window(for session: WorkoutSession) -> (start: Date, duration: TimeInterval, basis: DurationBasis)? {
        if let span = session.loggedSpan, span.duration >= shortest {
            return (span.start, span.duration, .loggedSpan)
        }
        if let duration = session.duration {
            return (session.date, duration, .startToFinish)
        }
        return nil
    }

    public static func check(_ duration: TimeInterval) -> DurationCheck {
        if duration < shortest { return .tooShort }
        if duration > longest { return .unusuallyLong }
        return .plausible
    }

    /// `(MET − 1) × kg × hours`.
    ///
    /// One MET is what the body burns at rest, and Apple Health keeps that
    /// separately as basal energy; counting it here too would add the resting
    /// burn of the session's hour a second time. Zero for anything without a
    /// positive weight or duration.
    public static func activeKilocalories(effort: Effort, weightKG: Double, duration: TimeInterval) -> Double {
        guard weightKG > 0, duration > 0 else { return 0 }
        return (effort.met - 1) * weightKG * duration / 3600
    }
}
