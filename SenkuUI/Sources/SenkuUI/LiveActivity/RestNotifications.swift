import Foundation
import SenkuCore

#if canImport(UserNotifications) && !os(macOS)
// `UNUserNotificationCenter` is thread-safe and documented as such, but is
// not marked `Sendable`, so passing it into the completion handlers it hands
// you is an error the module itself makes unavoidable.
@preconcurrency import UserNotifications

/// Fires a notification when a rest ends while Senku is not on screen.
///
/// The chime in ``Feedback`` only plays while the app is foregrounded, which is
/// the wrong half of the problem: the case that matters is the phone locked in
/// a pocket between sets. A local notification is the only thing that reaches
/// you there without keeping the app awake.
///
/// It is scheduled from the timer's absolute `endsAt`, so the system owns the
/// firing and Senku can be suspended or killed in the meantime. Anything that
/// moves the deadline — pause, reset, retarget, extend — reschedules, because a
/// notification that outlives its timer is worse than none.
public enum RestNotifications {
    private static let identifier = "senku.rest.finished"

    /// Left over from an experiment worth recording: a second, silent
    /// notification scheduled to arrive later cannot sweep the first away,
    /// because delivering a local notification does not wake the app. iOS has
    /// no expiry for a delivered notification at all, so the only thing that
    /// clears one is the app being run — see ``clearDelivered``.
    private static let sweepIdentifier = "senku.rest.finished.sweep"

    /// The alert sound. It must live in the **app's** bundle — iOS will not
    /// load a notification sound from a package resource bundle — which is why
    /// a copy of this file sits in the app target as well as in `SenkuUI`.
    ///
    /// watchOS has no custom notification sounds at all; it decides for itself
    /// how to alert, and the haptic is the part that matters there anyway.
    private static var alertSound: UNNotificationSound {
        #if os(watchOS)
        .default
        #else
        UNNotificationSound(named: UNNotificationSoundName("rest-complete.wav"))
        #endif
    }

    public static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Whether an alert would actually reach the user.
    ///
    /// Asked by the timer screen so that "you will not be told when this ends"
    /// is something the app says out loud. Scheduling into a denied permission
    /// fails silently, which is the worst way for a rest timer to be wrong: it
    /// looks like it is working right up until the set you miss.
    public static func canAlert() async -> Bool {
        // `.ephemeral` is an App Clip status and does not exist on watchOS, so
        // the two that matter everywhere are the two named here.
        switch await authorizationStatus() {
        case .authorized, .provisional: true
        default: false
        }
    }

    /// Asks, once, if the answer is not yet known.
    /// - Returns: whether alerts can now be delivered.
    @discardableResult
    public static func requestAuthorization() async -> Bool {
        #if DEBUG
        // A screenshot run must not be interrupted by a permission sheet — see
        // `SENKU_SCREEN` in `RootView`. Only ever set by hand, in a debug build.
        if ProcessInfo.processInfo.environment["SENKU_SCREEN"] != nil { return false }
        #endif

        let status = await authorizationStatus()
        guard status == .notDetermined else {
            return status == .authorized || status == .provisional
        }
        return (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Brings the pending notification in line with `timer`. Safe to call on
    /// every change; it cancels first, so it cannot leave a stale one behind.
    ///
    /// Asking for permission and scheduling have to happen in that order. They
    /// previously did not: the request was fired off alongside the schedule, so
    /// on the very first rest the notification was registered before the user
    /// had granted anything and iOS dropped it silently — and nothing ever
    /// rescheduled it. That first rest was the one most likely to be tested.
    public static func sync(with timer: RestTimer, at now: Date = .now) {
        // A finished timer keeps its alert. This is the whole bug that made a
        // rest land in silence: `endsAt` is nil the moment the crossing is
        // recorded, so a sync at zero fell straight through the guard below —
        // but not before `cancel()` had already deleted the pending request
        // that was about to fire, a fraction of a second early. The app was
        // reliably destroying its own alert in the act of noticing it was due.
        //
        // Nothing needs cancelling there in any case: a notification that has
        // already been delivered is cleared when the app is next opened, and
        // the next `start` cancels before scheduling.
        guard !timer.hasFinished(at: now) else { return }

        cancel()
        guard let endsAt = timer.endsAt, endsAt > now else { return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    schedule(endsAt: endsAt)
                }
            case .authorized, .provisional, .ephemeral:
                schedule(endsAt: endsAt)
            default:
                break // Denied. Nothing useful to do but stay quiet.
            }
        }
    }

    /// How long after the deadline the notification arrives, on the phone.
    ///
    /// The app sounds its own chime at zero through a held audio session, and a
    /// notification landing in the same instant cuts it off — iOS gives the
    /// alert the audio route and the chime stops mid-ring. Three seconds is
    /// enough for the chime to finish and short enough that nobody reads it as
    /// a late timer.
    ///
    /// None on the watch, where the notification *is* the alert and a delay
    /// would be a delay in being told.
    private static var chimeGrace: TimeInterval {
        #if os(watchOS)
        0
        #else
        3
        #endif
    }

    private static func schedule(endsAt: Date) {
        // Measured fresh rather than from the caller's `now`: asking for
        // permission can sit on screen for a while first.
        let seconds = endsAt.timeIntervalSinceNow + chimeGrace
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Time for your next set."
        content.sound = alertSound
        content.interruptionLevel = .timeSensitive

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            )
        )
    }

    /// Clears the notification both ways: the one still waiting to fire, and
    /// the one already sitting in Notification Center.
    ///
    /// Cancelling only the pending request was half a job. Reset a rest that
    /// had already ended and the alert stayed on the lock screen announcing a
    /// timer that no longer existed — the app said the rest was over and gone,
    /// and the notification said it was still there.
    public static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier, sweepIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier, sweepIdentifier])
    }

    /// Takes down an alert that has already been shown, leaving anything still
    /// scheduled alone.
    ///
    /// iOS has no way to give a local notification an expiry — a delivered one
    /// sits in Notification Center until it is swiped — so the app clears its
    /// own at every point where it can tell the alert has served its purpose:
    /// opening the app, starting the next rest, ending one from the Dynamic
    /// Island, or the count-up giving up.
    public static func clearDelivered() {
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [identifier, sweepIdentifier])
    }
}
#endif
