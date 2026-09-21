import Foundation
import SenkuCore

#if os(watchOS)
import WatchKit

/// Keeps the watch app alive to the end of a rest, and taps you when it lands.
///
/// ## Why a local notification is not enough
///
/// With the app off screen, watchOS suspends it: the tick stops, and the chime
/// the app would have played never happens. A scheduled notification is the
/// documented answer and it does fire — but it is delivered on the system's
/// terms, is silent when the watch is muted, and can be missed entirely.
///
/// `WKExtendedRuntimeSession` is the mechanism meant for this shape of problem.
/// While one is running the app keeps executing in the background, so the timer
/// reaches its own deadline, and `notifyUser(hapticType:)` exists precisely to
/// alert someone whose wrist is down. Both are used: the session is the alert
/// that works, the notification is the fallback if the session is ended early.
///
/// The session is started when a rest starts and ended the moment it is not
/// needed. It is not a background pass to be held open — an idle session is a
/// battery cost with nothing to show for it.
///
/// ## The Info.plist half
///
/// A session only starts if the app declares a matching `WKBackgroundModes`.
/// Senku declares `self-care`, the closest honest fit for a rest between sets:
/// a timed interval where the point is that you are *not* doing anything.
///
/// ## Isolation
///
/// Main-actor isolated: `WKExtendedRuntimeSession` is UI-adjacent state with a
/// delegate the system calls on the main thread, and every caller here is a
/// view. That is a simpler guarantee than making the handle `Sendable`.
@MainActor
public final class RestRuntimeSession: NSObject, @preconcurrency WKExtendedRuntimeSessionDelegate {
    public static let shared = RestRuntimeSession()

    /// Whether the system actually granted a session.
    ///
    /// Worth showing, not just tracking. A session is what keeps the app in
    /// front with the screen awake, so its absence is visible to the user
    /// anyway — as a watch that blanks mid-rest. Better to say which it is than
    /// to let the screen going dark be the only symptom.
    public private(set) var isHolding = false

    private var session: WKExtendedRuntimeSession?

    /// Fires the haptic at the deadline, owned here rather than by the screen.
    private var alarm: Timer?

    /// Where this session has got to with the rest it is holding.
    ///
    /// The landing — chime and haptic — happens exactly once, and this is what
    /// guarantees it. Two things notice a rest ending, the session's own alarm
    /// and the screen's tick, and they arrive in either order.
    private enum Landing: Equatable, CustomStringConvertible {
        var description: String {
            switch self {
            case .none: "none"
            case .booked(let at): "booked(\(at.timeIntervalSinceNow)s)"
            case .done: "done"
            }
        }

        /// No rest, or one still running with no alarm booked yet.
        case none
        /// An alarm is booked for this deadline and has not fired.
        case booked(Date)
        /// The chime and haptic have been fired for this rest.
        case done
    }

    private var landing: Landing = .none

    /// What the last landing actually managed to do.
    ///
    /// Shown on the screen, because a rest that ends without a sound and one
    /// that ends with a sound you did not hear look identical from the outside
    /// — and the difference is whether the watch is muted or the app is broken.
    /// Nothing else can tell you which.
    public struct LandingReport: Sendable, Equatable {
        /// Whether the wrist was tapped through the runtime session, rather
        /// than through the fallback haptic.
        public var heldSession: Bool
        /// Whether the chime played. `nil` while the audio route is still
        /// being decided — watchOS answers that asynchronously.
        public var chimeSounded: Bool?
    }

    public private(set) var lastLanding: LandingReport?

    private override init() { super.init() }

    /// Starts a session if one is not already running.
    public func begin() {
        guard session == nil else { return }
        let new = WKExtendedRuntimeSession()
        new.delegate = self
        session = new
        new.start()
    }

    /// Taps the wrist, repeatedly.
    ///
    /// One tap is missable — a wrist at your side during a set, a bar in your
    /// hands — so this repeats for about ten seconds. It is the watch's
    /// counterpart to the phone's alert being three triplets rather than one
    /// polite chime.
    ///
    /// ## Why not `notifyUser(hapticType:)`
    ///
    /// Because it kills the app. It reads like exactly the right call — the
    /// system's own "alert someone whose wrist is down", with a repeat handler
    /// built in — and this code used it for months. But it is only legal during
    /// a **smart alarm** session. Senku holds a *self-care* session, which is
    /// the honest declaration for a rest between sets, and calling `notifyUser`
    /// on one raises an Objective-C exception: `signal 6`, before the next line
    /// runs.
    ///
    /// That was the whole mystery. Every rest that reached zero on the wrist
    /// crashed the watch app on the spot — which is why it returned to the
    /// watch face the instant the timer hit zero, why the chime queued on the
    /// line below never played, and why the notification that used to exist
    /// turned up twenty seconds later, once the system had cleaned up after the
    /// process that was supposed to have handled it.
    public func alert() {
        Trace.rest("alert: session=\(session.map { String($0.state.rawValue) } ?? "none")")
        lastLanding = LandingReport(heldSession: session?.state == .running, chimeSounded: nil)

        playHaptics()
    }

    /// Six buzzes on the wrist, a second and a bit apart.
    ///
    /// ## Why clicks and not `.notification`
    ///
    /// `.notification` is the obvious haptic to reach for, and it is the wrong
    /// one here: watchOS pairs it with the standard alert *sound*, and the two
    /// cannot be separated. So every buzz came with a ding on top of Senku's
    /// own chime — two different noises announcing the same thing, one of them
    /// not even ours.
    ///
    /// `.click` is the silent one, the crown-detent tick. On its own it is far
    /// too light to notice mid-set, so each buzz is a short burst of them,
    /// which reads on the wrist as a vibration rather than a tap.
    private func playHaptics() {
        // Bounded by wall clock rather than by a counter: a captured counter
        // mutated inside a timer's closure is a data race the compiler is
        // right to warn about, and a throttled tick cannot stretch a deadline.
        let stop = Date.now.addingTimeInterval(Double(Self.pulses - 1) * Self.pulseGap)
        buzz()

        let repeater = Timer(timeInterval: Self.pulseGap, repeats: true) { fired in
            guard Date.now < stop else { return fired.invalidate() }
            Task { @MainActor in RestRuntimeSession.shared.buzz() }
        }
        RunLoop.main.add(repeater, forMode: .common)
    }

    /// One buzz: several clicks close enough together to feel continuous.
    private func buzz() {
        let device = WKInterfaceDevice.current()
        device.play(.click)

        for step in 1..<Self.clicksPerBuzz {
            let delay = Double(step) * Self.clickGap
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                device.play(.click)
            }
        }
    }

    /// How many times the wrist is buzzed, and how far apart.
    ///
    /// One is missable — a wrist at your side, a bar in your hands — which is
    /// why it repeats at all.
    private static let pulses = 6
    private static let pulseGap: TimeInterval = 1.2

    /// What one buzz is made of. Six clicks at 60 ms is a third of a second of
    /// vibration, which is short enough not to be a nuisance and long enough
    /// to be felt through a sleeve.
    private static let clicksPerBuzz = 6
    private static let clickGap: TimeInterval = 0.06

    public func end() {
        Trace.rest("end: releasing session")
        alarm?.invalidate()
        alarm = nil
        landing = .none
        session?.invalidate()
        session = nil
        isHolding = false
    }

    /// Mirrors the timer. Called from the one place every mutation passes
    /// through, so a new control cannot forget it.
    ///
    /// The alarm is scheduled **here**, not left to the screen's tick. That was
    /// the flaw in the first attempt: the session kept the app alive, but the
    /// countdown that noticed the deadline lived in a SwiftUI view, and a view
    /// off screen is not guaranteed to be receiving anything. A run-loop timer
    /// owned by the session has no such dependency.
    public func sync(with timer: RestTimer, at now: Date = .now) {
        // A rest that has just *finished* is the one moment the session must
        // not be torn down. Ending it invalidates the haptic that was asked for
        // microseconds earlier, which is exactly how a timer comes to run to
        // zero, blank the screen and say nothing. So the session is held open
        // for the alert and wound down afterwards.
        //
        // ## Why this is a switch and not a wind-down
        //
        // Two things notice the deadline: the alarm booked below, and the
        // screen's tick, which reports the crossing through the view's
        // `changed(at:)` and arrives here. Whichever is second used to find a
        // session being wound down — and `windDown` invalidates `alarm`, which
        // *is* the timer that calls `land()`. When the tick won that race the
        // landing was cancelled before it ever fired, and a rest run to zero on
        // the watch made no sound and no tap at all.
        //
        // So the crossing is not a cancellation. Whoever notices it first does
        // the landing, `land()` runs once, and nothing here cuts it short.
        if timer.hasFinished(at: now) {
            Trace.rest("sync: finished, landing=\(landing)")
            switch landing {
            case .booked: land()
            case .done: break
            case .none: end()
            }
            return
        }

        guard timer.isRunning, let endsAt = timer.endsAt else {
            end()
            return
        }

        begin()
        // Open the audio route now rather than at the deadline. watchOS decides
        // where a sound is going — speaker, or whatever is paired — and does it
        // asynchronously, so asking as the chime is due is asking too late.
        Feedback.prepareChime()
        scheduleAlarm(at: endsAt)
    }

    /// The rest lands: make the noise, then hand the screen back.
    ///
    /// This is the session earning its keep. It is awake at the deadline
    /// whether or not the screen is on, which the countdown view is not — so
    /// the alert belongs here rather than in a tick that stops being delivered
    /// the moment the wrist drops.
    ///
    /// The app holds on afterwards rather than getting out of the way, because
    /// it is now the thing alerting you: the chime plays, the haptic repeats,
    /// and fifteen seconds is long enough for both to finish and be noticed.
    private func land() {
        guard landing != .done else {
            Trace.rest("land: already done, ignoring")
            return
        }
        Trace.rest("land: firing")
        landing = .done

        alert()

        Feedback.chime { [weak self] sounded in
            Task { @MainActor in self?.soundLanded(sounded) }
        }

        windDown(after: Self.alertDuration)
    }

    /// How long the session is held after a rest lands.
    ///
    /// Derived from the alert rather than chosen, because the two were set in
    /// different places for different reasons and drifted apart: the haptics
    /// ran for six seconds while the session was released after three, so the
    /// app was suspended halfway through and half the buzzes never happened.
    /// Releasing the session is what ends the alert, so it cannot be shorter
    /// than the alert it is holding open for.
    private static var alertDuration: TimeInterval {
        // The last buzz, plus a moment to finish; the chime is two seconds and
        // comfortably inside it.
        Double(pulses - 1) * pulseGap + 1
    }

    /// Whether the notification is still needed.
    ///
    /// Only a chime that actually played earns the right to suppress it. If the
    /// audio route was refused — headphones mid-handoff, a session the system
    /// would not activate — the notification is left exactly where it is, and
    /// surfaces when this session ends. The alternative is an app that assumes
    /// it made a sound and leaves you with none.
    private func soundLanded(_ sounded: Bool) {
        Trace.rest("soundLanded: \(sounded)")
        lastLanding?.chimeSounded = sounded

        guard sounded else {
            // Nothing to wait for, so nothing to hold the screen for.
            windDown(after: 0.5)
            return
        }
    }

    /// Gives the session back, a moment after the rest lands.
    ///
    /// It was fifteen seconds while the session was the thing alerting you and
    /// needed to outlive its own repeating haptic. The notification does that
    /// job now, so the only reason to hold on at all is to let the last tick
    /// settle — and holding longer was actively wrong: the app stays in front
    /// until the session ends, and the alert waiting behind it only appears
    /// once it does.
    private func windDown(after seconds: TimeInterval = 2) {
        Trace.rest("windDown: in \(seconds)s")
        alarm?.invalidate()

        let closing = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.end() }
        }
        RunLoop.main.add(closing, forMode: .common)
        alarm = closing
    }

    /// At the deadline, the session's job is done — so it gets out of the way.
    ///
    /// This used to fire ``alert()``, and that was the last thing standing
    /// between a finished rest and the alert for it. `notifyUser` keeps the app
    /// in front for as long as it repeats — about ten seconds — and a
    /// notification cannot be shown over the app that is frontmost, so it waited
    /// there until the repetition ended and the session let go. The alert
    /// arriving a quarter of a minute late was the session alerting *instead*
    /// of it, silently, and then finally standing aside.
    ///
    /// Fires ``land()`` on the deadline itself.
    ///
    /// Not a second early and not a second late: ending the session at the
    /// deadline suspended the app mid-count and froze the display on 0:01, and
    /// anything later is an alert that arrives after the rest it is announcing.
    private static let handoverDelay: TimeInterval = 0

    private func scheduleAlarm(at date: Date) {
        guard landing != .booked(date) else { return }
        Trace.rest("scheduleAlarm: in \(date.timeIntervalSinceNow)s")
        alarm?.invalidate()
        landing = .booked(date)
        // A new rest: last time's outcome is not this rest's news.
        lastLanding = nil

        let fireTimer = Timer(
            timeInterval: max(0.1, date.timeIntervalSinceNow + Self.handoverDelay),
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in self?.land() }
        }
        // `.common` so it still fires while the watch is scrolling or the app
        // is not the thing on screen.
        RunLoop.main.add(fireTimer, forMode: .common)
        alarm = fireTimer
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    public func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {
        isHolding = true
    }

    /// The system warns before it takes the session away. Nothing to save here
    /// — the timer's deadline is already on disk — so this is left deliberately
    /// empty rather than made to look busy.
    public func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {}

    public func extendedRuntimeSession(
        _ session: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        // Dropped rather than retried: a session the system has just taken back
        // will not be handed over again by asking twice, and the scheduled
        // notification is still there to cover the landing.
        self.session = nil
        isHolding = false
    }
}
#endif
