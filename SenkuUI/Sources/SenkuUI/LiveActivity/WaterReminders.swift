#if canImport(UserNotifications) && !os(macOS)
import Foundation
import UserNotifications
import SenkuCore

/// Reminders to drink, inside a budget.
///
/// ## The 64
///
/// iOS holds at most 64 *pending* requests per app, keeps the soonest-firing 64
/// and silently discards the rest — no error, nothing to catch. Reminding
/// someone every two hours from eight to ten, scheduled a week out, is 56
/// one-shot requests; every half hour is 196, of which 132 vanish. Worse, the
/// ones dropped are the furthest away, so the failure looks like "reminders
/// stopped working on Thursday".
///
/// So each slot is **one repeating calendar trigger**: 08:00, 10:00, 12:00 and
/// so on, eight of them for the default settings, scheduled once and never
/// topped up. They fire every day for as long as they exist and occupy eight of
/// the sixty-four permanently.
///
/// Ceiling, stated so it can be checked: **`maxSlots` (12) water + 1 weigh-in +
/// 1 rest = 14 of 64.** The rest timer is the one that must never be crowded
/// out, and it always fires within minutes, so even a full queue could not
/// displace it.
///
/// ## Stopping once the target is met
///
/// Nagging past success is how a reminder gets switched off for good, so the
/// remaining slots for *today* are cancelled when the target is reached and put
/// back the next time the app runs. That is the one thing repeating triggers do
/// not do for free — the cost of not having to top them up.
public enum WaterReminders {
    static let prefix = "senku.water.reminder."
    static let categoryID = "senku.water"
    static let logActionID = "senku.water.log"

    /// A ceiling with room to spare, and the reason there is one: an hourly
    /// window of fourteen hours would otherwise book fourteen.
    static let maxSlots = 12

    /// The hours a reminder can land on, from the settings.
    static func slots(_ settings: WaterStore.Settings) -> [DateComponents] {
        let step = max(30, settings.reminderIntervalMinutes)
        var minutes = settings.reminderStartHour * 60
        let end = settings.reminderEndHour * 60
        var slots: [DateComponents] = []

        while minutes <= end, slots.count < maxSlots {
            var components = DateComponents()
            components.hour = minutes / 60
            components.minute = minutes % 60
            slots.append(components)
            minutes += step
        }
        return slots
    }

    /// Registers the "Log a glass" button so the common case never opens the app.
    public static func registerCategory(_ containers: [WaterContainer]) {
        let container = containers.first ?? WaterContainer(name: "Glass", millilitres: 250)

        let action = UNNotificationAction(
            identifier: logActionID,
            title: "Log \(Int(container.millilitres)) ml",
            options: []          // no `.foreground`: handled with the app in the background
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(
                identifier: categoryID,
                actions: [action],
                intentIdentifiers: [],
                options: []
            )
        ])
    }

    /// Books every slot, or clears them all when the switch is off.
    @discardableResult
    public static func schedule(_ settings: WaterStore.Settings) async -> Bool {
        cancelAll()
        guard settings.remindersOn else { return true }

        let centre = UNUserNotificationCenter.current()
        let status = await centre.notificationSettings().authorizationStatus

        var granted = status == .authorized || status == .provisional
        if status == .notDetermined {
            granted = (try? await centre.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        guard granted else { return false }

        registerCategory(settings.containers)

        for (index, slot) in slots(settings).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Water"
            content.body = "Time for a drink."
            content.sound = .default
            content.categoryIdentifier = categoryID

            try? await centre.add(
                UNNotificationRequest(
                    identifier: "\(prefix)\(index)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: slot, repeats: true)
                )
            )
        }
        return true
    }

    /// Silences the rest of today once the target is met, and restores the
    /// schedule when it is not.
    ///
    /// Takes the settings by value rather than the store: the work continues on
    /// a task, and handing a reference to an observable object across that
    /// boundary is the data race the compiler is right to refuse.
    public static func refresh(settings: WaterStore.Settings, isMet: Bool) {
        guard settings.remindersOn else { return }

        if isMet {
            silenceRestOfToday(settings)
        } else {
            Task { await schedule(settings) }
        }
    }

    /// Removes the slots still to come today, leaving the earlier ones — which
    /// are already past — to fire again tomorrow.
    ///
    /// A repeating request cannot skip one occurrence, so the only way to stop
    /// today without stopping every day is to remove and re-add it. The re-add
    /// happens the next time the app is opened; if it never is, tomorrow's
    /// reminders are missing, which is the honest cost of this approach and the
    /// reason `refresh` runs on every launch of the water screen.
    private static func silenceRestOfToday(_ settings: WaterStore.Settings) {
        let calendar = Calendar.current
        let now = calendar.dateComponents([.hour, .minute], from: .now)
        let nowMinutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)

        let doomed = slots(settings).enumerated().compactMap { index, slot -> String? in
            let slotMinutes = (slot.hour ?? 0) * 60 + (slot.minute ?? 0)
            return slotMinutes > nowMinutes ? "\(prefix)\(index)" : nil
        }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: doomed)
    }

    public static func cancelAll() {
        let identifiers = (0 ..< maxSlots).map { "\(prefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
#endif
