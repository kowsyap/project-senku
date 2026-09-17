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
    /// hands — so this repeats for about ten seconds unless the session is
    /// taken away first. It is the watch's counterpart to the phone's alert
    /// being three triplets rather than one polite chime.
    public func alert() {
        guard let session, session.state == .running else { return }

        let stop = Date.now.addingTimeInterval(10)
        session.notifyUser(hapticType: .notification) { _ in
            // The returned interval is the wait before the next tap; zero ends
            // the repetition. Bounded by wall clock rather than by a counter,
            // so a throttled callback cannot stretch it into a nuisance.
            Date.now < stop ? 1.2 : 0
        }
    }

    public func end() {
        alarm?.invalidate()
        alarm = nil
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
        if timer.hasFinished(at: now) {
            windDown()
            return
        }

        guard timer.isRunning, let endsAt = timer.endsAt else {
            end()
            return
        }

        begin()
        scheduleAlarm(at: endsAt)
    }

    /// Lets the alert play out, then gives the session back.
    private func windDown() {
        alarm?.invalidate()

        let closing = Timer(timeInterval: 15, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.end() }
        }
        RunLoop.main.add(closing, forMode: .common)
        alarm = closing
    }

    private func scheduleAlarm(at date: Date) {
        alarm?.invalidate()

        let fireTimer = Timer(
            timeInterval: max(0.1, date.timeIntervalSinceNow),
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in self?.alert() }
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
