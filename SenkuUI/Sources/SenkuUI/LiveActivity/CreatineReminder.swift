#if canImport(UserNotifications) && !os(macOS)
import Foundation
import UserNotifications

/// A daily nudge to take creatine.
///
/// One repeating trigger, like the weigh-in reminder and for the same reason:
/// the 64-request budget is shared across the whole app, and a month of
/// individual days would spend half of it on one habit. This is request number
/// two of an app-wide fourteen — see `WaterReminders` for the arithmetic.
///
/// Ten in the morning because creatine works by saturation rather than by
/// timing: the dose matters, the hour does not, so the reminder goes where it
/// is most likely to be acted on rather than at some notionally optimal time.
public enum CreatineReminder {
    static let identifier = "senku.creatine.reminder"
    static let storageKey = "senku.creatineReminder.v1"

    public static let hour = 10

    public static var isOn: Bool {
        get { SenkuStorage.shared.bool(forKey: storageKey) }
        set { SenkuStorage.shared.set(newValue, forKey: storageKey) }
    }

    @discardableResult
    public static func enable() async -> Bool {
        let centre = UNUserNotificationCenter.current()

        let settings = await centre.notificationSettings()
        var granted = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional

        if settings.authorizationStatus == .notDetermined {
            granted = (try? await centre.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        guard granted else {
            isOn = false
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "Creatine"
        content.body = "Take it today — it works by staying topped up."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = 0

        centre.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await centre.add(
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
        )

        isOn = true
        return true
    }

    public static func disable() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
        isOn = false
    }

    /// Re-books it if it should be on, and cancels it if creatine has been
    /// switched off entirely — a reminder for a supplement you no longer take
    /// is the fastest way to teach someone to ignore notifications.
    public static func refresh(takesCreatine: Bool) async {
        guard takesCreatine else {
            if isOn { disable() }
            return
        }
        guard isOn else { return }
        await enable()
    }
}
#endif
