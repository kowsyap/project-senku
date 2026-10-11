#if canImport(UserNotifications) && !os(macOS)
import Foundation
import UserNotifications

/// A morning nudge to stand on the scales — on the mornings you have not.
///
/// ## Why a week of one-shots and not one repeating trigger
///
/// It was one repeating trigger, which is the cheapest thing iOS offers and
/// cannot skip a day: it rang at ten whether or not you had weighed in at
/// seven. So the reminder is booked a morning at a time, for the next seven,
/// leaving out any morning that already has a weigh-in — and booked again
/// whenever a weigh-in is logged or deleted and whenever the app comes forward.
///
/// The cost is the week's horizon. A repeating trigger runs forever; this runs
/// out a week after the app was last opened. That is the right failure: a
/// week of not opening the app is a week of not logging, and a reminder about
/// that is for the app to make when you come back, not for the lock screen to
/// make indefinitely. Seven requests come out of `NotificationBudget`.
public enum WeightReminder {
    /// The old repeating request — removed on sight, so a phone that had it
    /// does not ring twice.
    static let legacyIdentifier = "senku.weight.reminder"
    static let prefix = "senku.weight.reminder."
    static let storageKey = "senku.weightReminder.v1"

    /// The hour, fixed at ten. A picker is a setting to design, a screen to
    /// build and a thing to explain; ten in the morning is after most people
    /// have got up and before the day's food and water make the number
    /// meaningless, which is the whole reason weight is taken in the morning.
    public static let hour = 10

    /// How many mornings are booked ahead.
    static var mornings: Int { NotificationBudget.allocation(.weighIn) }

    public static var isOn: Bool {
        get { SenkuStorage.shared.bool(forKey: storageKey) }
        set { SenkuStorage.shared.set(newValue, forKey: storageKey) }
    }

    /// Turns it on, asking for permission if this is the first alert the app
    /// has ever wanted. Returns what actually happened, so a refused permission
    /// can put the switch back rather than leaving it on and silent.
    @MainActor
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

        isOn = true
        await book()
        return true
    }

    @MainActor
    public static func disable() {
        isOn = false
        Task { await removeBooked() }
    }

    /// Re-books it if it should be on: after a weigh-in is logged or deleted,
    /// when the app comes forward, and when the weight screen appears — a
    /// pending request can be lost to a restore or to notifications being
    /// switched off and on, while the switch here still says it is on.
    @MainActor
    public static func refresh() async {
        guard isOn else { return }
        await book()
    }

    @MainActor
    private static func book() async {
        await removeBooked()
        let centre = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Weigh in"
        content.body = "Same time, same scales — it is the consistency that makes the trend mean anything."
        content.sound = .default

        let calendar = Calendar.current
        let weighedIn = WeightLogStore().weighIns.map(\.date)
        let plan = WeighInReminderPlan.mornings(from: .now, weighedIn: weighedIn, hour: hour, count: mornings, calendar: calendar)
        for moment in plan {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: moment)
            try? await centre.add(
                UNNotificationRequest(
                    identifier: prefix + moment.formatted(.iso8601.year().month().day()),
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
            )
        }
    }

    private static func removeBooked() async {
        let centre = UNUserNotificationCenter.current()
        let ours = await centre.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0 == legacyIdentifier || $0.hasPrefix(prefix) }
        centre.removePendingNotificationRequests(withIdentifiers: ours)
    }
}
#endif
