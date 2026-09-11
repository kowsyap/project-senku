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
/// notification that survives its timer is worse than none.
public enum RestNotifications {
    private static let identifier = "senku.rest.finished"

    /// Asked for the first time a rest is actually started, rather than at
    /// launch. Someone who never opens the timer is never prompted.
    public static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Brings the pending notification in line with `timer`. Safe to call on
    /// every change; it cancels first, so it cannot leave a stale one behind.
    public static func sync(with timer: RestTimer, at now: Date = .now) {
        cancel()

        // Only a running timer has a deadline to fire at. A paused one is
        // waiting on the user, and an idle or finished one has nothing to say.
        guard let endsAt = timer.endsAt, endsAt > now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Time for your next set."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: identifier,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: endsAt.timeIntervalSince(now),
                repeats: false
            ),
            content: content
        )
        UNUserNotificationCenter.current().add(request)
    }

    public static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

private extension UNNotificationRequest {
    convenience init(
        identifier: String,
        trigger: UNNotificationTrigger,
        content: UNNotificationContent
    ) {
        self.init(identifier: identifier, content: content, trigger: trigger)
    }
}
#endif
