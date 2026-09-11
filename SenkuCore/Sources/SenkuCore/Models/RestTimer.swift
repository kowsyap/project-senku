import Foundation

/// A rest timer between sets.
///
/// ## Why this stores a deadline rather than a countdown
///
/// The obvious implementation keeps a `remaining` number and subtracts from it
/// on a tick. That implementation is wrong for this app, and quietly so: the
/// moment the phone locks or the app is suspended the ticks stop, and the timer
/// comes back under by however long it was away. A rest timer you cannot trust
/// with the screen off is not a rest timer.
///
/// So a running timer stores the absolute `Date` it ends at, and every
/// question about it is answered as a pure function of a caller-supplied `now`.
/// Nothing here schedules work, observes a clock, or needs to stay resident.
/// That buys three things at once:
///
/// - suspension and lock cost nothing, because no state decays while away;
/// - a Live Activity can be handed `endsAt` and animate on its own, with no
///   process of ours awake to feed it;
/// - the whole thing is testable by passing dates, with no waiting.
///
/// Pausing is the one case that cannot hold a deadline — a paused timer has no
/// end date yet — so it banks the remaining interval instead and converts back
/// to a deadline on resume.
public struct RestTimer: Hashable, Sendable, Codable {
    /// Shortest and longest rest a timer will accept. The floor keeps a stray
    /// tap from creating a timer that fires before it can be read; the ceiling
    /// is well past any real rest interval.
    public static let allowedDuration: ClosedRange<TimeInterval> = 5...3600

    public enum Phase: Hashable, Sendable, Codable {
        /// Set up but not started. Reads as a full `duration`.
        case idle
        /// Counting down towards an absolute deadline.
        case running(endsAt: Date)
        /// Held, with the interval that was left when it was held.
        case paused(remaining: TimeInterval)
        /// Reached zero at this instant.
        case finished(at: Date)
    }

    /// The interval this timer was set for. Unchanged by pausing or resuming,
    /// so `progress` always measures against what the user actually asked for.
    public private(set) var duration: TimeInterval
    public private(set) var phase: Phase

    // MARK: - Creating

    /// - Throws: `ValidationError.restDurationOutOfRange` outside
    ///   ``allowedDuration``. Validating here means no method below has to
    ///   defend itself against a nonsense interval.
    public init(duration: TimeInterval) throws {
        guard Self.allowedDuration.contains(duration) else {
            throw ValidationError.restDurationOutOfRange(duration)
        }
        self.duration = duration
        self.phase = .idle
    }

    /// Presets are in range by construction, so this cannot fail.
    public init(preset: RestPreset) {
        self.duration = preset.duration
        self.phase = .idle
    }

    // MARK: - Reading
    //
    // Every one of these is a pure function of `now`. None of them mutate, so
    // a view can call them as often as it redraws.

    /// Time left, clamped at zero. A finished or elapsed timer reads `0`.
    public func remaining(at now: Date) -> TimeInterval {
        switch phase {
        case .idle: duration
        case .running(let endsAt): max(0, endsAt.timeIntervalSince(now))
        case .paused(let remaining): remaining
        case .finished: 0
        }
    }

    /// How far through, from `0` at the start to `1` at the buzzer.
    public func progress(at now: Date) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, 1 - remaining(at: now) / duration))
    }

    /// How long ago it hit zero, or `0` if it has not. Lets the UI say
    /// "finished 40s ago" rather than sitting on a bare `0:00`.
    public func overrun(at now: Date) -> TimeInterval {
        switch phase {
        case .running(let endsAt): max(0, now.timeIntervalSince(endsAt))
        case .finished(let at): max(0, now.timeIntervalSince(at))
        case .idle, .paused: 0
        }
    }

    /// The deadline to hand a Live Activity or a local notification. `nil`
    /// whenever there is no deadline to give — idle, paused, or already done.
    public var endsAt: Date? {
        if case .running(let endsAt) = phase { return endsAt }
        return nil
    }

    public var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    public var isIdle: Bool {
        if case .idle = phase { return true }
        return false
    }

    /// True once the timer has reached zero, whether or not ``refresh(at:)``
    /// has been called to record it. A caller that only ever asks this never
    /// has to remember to refresh.
    public func hasFinished(at now: Date) -> Bool {
        switch phase {
        case .finished: true
        case .running(let endsAt): now >= endsAt
        case .idle, .paused: false
        }
    }

    // MARK: - Driving
    //
    // Mutating rather than returning copies: a timer is the one genuinely
    // stateful thing in the core, and SwiftUI will hold it in `@State`. The
    // value semantics are unchanged either way.

    /// Starts, or restarts, a full `duration` from `now`.
    public mutating func start(at now: Date) {
        phase = .running(endsAt: now.addingTimeInterval(duration))
    }

    /// Banks what is left. A timer that has already elapsed finishes rather
    /// than parking at zero, so pausing cannot be used to dodge the buzzer.
    public mutating func pause(at now: Date) {
        guard case .running(let endsAt) = phase else { return }
        let left = endsAt.timeIntervalSince(now)
        phase = left <= 0 ? .finished(at: endsAt) : .paused(remaining: left)
    }

    /// Converts banked time back into a deadline.
    public mutating func resume(at now: Date) {
        guard case .paused(let remaining) = phase else { return }
        phase = .running(endsAt: now.addingTimeInterval(remaining))
    }

    /// Pause if running, resume if paused — the single button the UI wants.
    public mutating func toggle(at now: Date) {
        switch phase {
        case .running: pause(at: now)
        case .paused: resume(at: now)
        case .idle: start(at: now)
        case .finished: start(at: now)
        }
    }

    /// Back to a full, unstarted `duration`.
    public mutating func reset() {
        phase = .idle
    }

    /// Records the crossing from running to finished, stamped at the deadline
    /// rather than at `now`, so a late call does not drag the finish time with
    /// it. Returns `true` exactly once per run, which is the signal to fire a
    /// haptic or a sound.
    @discardableResult
    public mutating func refresh(at now: Date) -> Bool {
        guard case .running(let endsAt) = phase, now >= endsAt else { return false }
        phase = .finished(at: endsAt)
        return true
    }

    /// Extends the rest by `seconds`, the mid-set "I need a bit longer" case.
    /// Negative values shorten it.
    ///
    /// Adding to a finished timer restarts it for that much more rather than
    /// doing nothing, since that is the only reason to reach for it there.
    /// The result is always held inside ``allowedDuration``.
    public mutating func extend(by seconds: TimeInterval, at now: Date) {
        let left = remaining(at: now)
        let target = clampToAllowed(left + seconds)

        switch phase {
        case .idle:
            duration = target
        case .running:
            phase = .running(endsAt: now.addingTimeInterval(target))
            duration = clampToAllowed(duration + seconds)
        case .paused:
            phase = .paused(remaining: target)
            duration = clampToAllowed(duration + seconds)
        case .finished:
            guard seconds > 0 else { return }
            duration = clampToAllowed(seconds)
            phase = .running(endsAt: now.addingTimeInterval(duration))
        }
    }

    /// Swaps in a new interval. Restarts from the new figure if it was already
    /// running, since silently keeping the old deadline under a new label is
    /// the sort of quiet lie this app is supposed to avoid.
    public mutating func setDuration(_ newDuration: TimeInterval, at now: Date) throws {
        guard Self.allowedDuration.contains(newDuration) else {
            throw ValidationError.restDurationOutOfRange(newDuration)
        }
        duration = newDuration
        switch phase {
        case .running: phase = .running(endsAt: now.addingTimeInterval(newDuration))
        case .paused: phase = .paused(remaining: newDuration)
        case .idle, .finished: phase = .idle
        }
    }

    private func clampToAllowed(_ value: TimeInterval) -> TimeInterval {
        min(Self.allowedDuration.upperBound, max(Self.allowedDuration.lowerBound, value))
    }
}
