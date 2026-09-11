import Foundation
import SenkuCore

#if canImport(UserNotifications) && !os(macOS)
import UserNotifications

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

    /// Brings the pending notification in line with `timer`. Safe to call on
    /// every change; it cancels first, so it cannot leave a stale one behind.
    ///
    /// Asking for permission and scheduling have to happen in that order. They
    /// previously did not: the request was fired off alongside the schedule, so
    /// on the very first rest the notification was registered before the user
    /// had granted anything and iOS dropped it silently — and nothing ever
    /// rescheduled it. That first rest was the one most likely to be tested.
    public static func sync(with timer: RestTimer, at now: Date = .now) {
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

    private static func schedule(endsAt: Date) {
        // Measured fresh rather than from the caller's `now`: asking for
        // permission can sit on screen for a while first.
        let seconds = endsAt.timeIntervalSinceNow
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

    public static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
#endif
