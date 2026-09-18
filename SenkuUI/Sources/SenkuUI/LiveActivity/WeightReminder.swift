#if canImport(UserNotifications) && !os(macOS)
import Foundation
import UserNotifications

/// A daily nudge to stand on the scales.
///
/// ## Why one repeating trigger and not thirty
///
/// iOS allows 64 pending notifications per app, shared with the rest timer's.
/// Scheduling a month of individual reminders would spend half that budget on a
/// feature that can be expressed as one repeating trigger — and would run out
/// silently the month after. `UNCalendarNotificationTrigger` with `repeats`
/// fires every day at the hour for as long as it is scheduled.
///
/// It survives the app being closed, swiped out of the switcher, and a reboot,
/// because the schedule belongs to the system rather than to the app. The one
/// thing it cannot survive is never having been set: the app has to run once.
public enum WeightReminder {
    static let identifier = "senku.weight.reminder"
    static let storageKey = "senku.weightReminder.v1"

    /// The hour, fixed at ten. A picker is a setting to design, a screen to
    /// build and a thing to explain; ten in the morning is after most people
    /// have got up and before the day's food and water make the number
    /// meaningless, which is the whole reason weight is taken in the morning.
    public static let hour = 10

    public static var isOn: Bool {
        get { SenkuStorage.shared.bool(forKey: storageKey) }
        set { SenkuStorage.shared.set(newValue, forKey: storageKey) }
    }

    /// Turns it on, asking for permission if this is the first alert the app
    /// has ever wanted. Returns what actually happened, so a refused permission
    /// can put the switch back rather than leaving it on and silent.
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
        content.title = "Weigh in"
        content.body = "Same time, same scales — it is the consistency that makes the trend mean anything."
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

    /// Re-books it if it should be on.
    ///
    /// Called when the weight screen appears, because a pending request can be
    /// lost — by a restore, by notifications being turned off and on again in
    /// Settings — while the switch here still says it is on. Cheap enough to do
    /// every time, and the alternative is a reminder that quietly stopped.
    public static func refresh() async {
        guard isOn else { return }
        await enable()
    }
}
#endif
