#if canImport(UserNotifications) && !os(macOS)
import Foundation
import UserNotifications
import SenkuCore

/// Books what `DueReminderPlan` decides, and nothing else.
///
/// Every call clears the due-date requests and books the plan afresh. That is
/// cheaper than it sounds — at most `NotificationBudget.allocation(.dueDates)`
/// requests — and it means there is no state to drift: what is pending is
/// always exactly what the current list asks for.
public enum DueReminders {
    /// Rebuilds every due-date reminder. Asks for permission the first time
    /// there is something to remind about, and not before.
    @MainActor
    public static func refresh(_ items: [DueItem]) async {
        let plan = DueReminderPlan.plan(items, amount: DueFormat.amount)
        let centre = UNUserNotificationCenter.current()

        await cancelAll()
        guard !plan.reminders.isEmpty else { return }

        let settings = await centre.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            guard (try? await centre.requestAuthorization(options: [.alert, .sound])) == true else { return }
        } else if settings.authorizationStatus == .denied {
            return
        }

        for planned in plan.reminders {
            let content = UNMutableNotificationContent()
            content.title = planned.title
            content.body = planned.body
            content.sound = .default
            content.threadIdentifier = "senku.due"

            let parts = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: planned.fireAt
            )
            try? await centre.add(
                UNNotificationRequest(
                    identifier: planned.identifier,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                )
            )
        }
    }

    public static func cancelAll() async {
        let centre = UNUserNotificationCenter.current()
        let pending = await centre.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(DueReminderPlan.prefix) }
        centre.removePendingNotificationRequests(withIdentifiers: ours)
    }
}
#endif
