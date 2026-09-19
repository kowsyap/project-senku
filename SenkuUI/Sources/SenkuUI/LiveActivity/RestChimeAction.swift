import Foundation
import SenkuCore

/// What the chime should do about a timer in a given state.
///
/// Separated from `RestChime` itself, and deliberately not behind `#if
/// os(iOS)`, so the decision can be tested on the host — `RestChime` cannot be,
/// because everything it does is `AVAudioSession`.
///
/// The decision is the part that was wrong. A rest that *ends* and a rest that
/// is *stopped* both leave `isRunning` false and `endsAt` nil, so a check built
/// on those alone could not tell them apart and treated the end of a rest as a
/// cancellation — stopping the chime at the instant it was scheduled to start.
public enum RestChimeAction: Equatable, Sendable {
    /// Book the chime for this deadline and hold the audio session until then.
    case schedule(Date)
    /// The deadline has arrived. Let the chime sound, then release the session.
    case ringOut
    /// There is no rest. Stop anything playing and release the session.
    case stop

    public init(for timer: RestTimer, at now: Date) {
        if let endsAt = timer.endsAt, endsAt > now {
            self = .schedule(endsAt)
        } else if timer.hasFinished(at: now) {
            self = .ringOut
        } else {
            self = .stop
        }
    }
}
