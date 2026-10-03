import Foundation
import SenkuCore

/// One notification to book for a due date.
public struct PlannedReminder: Equatable, Sendable {
    public let identifier: String
    public let itemID: UUID
    public let fireAt: Date
    public let title: String
    public let body: String
}

/// Which reminders to book, inside the due-dates share of the 64.
///
/// ## One-shots, rebuilt whenever anything changes
///
/// Repeating calendar triggers are the cheap, set-and-forget option the water
/// and weigh-in reminders use, and they cannot do two things this needs: be
/// told that October is already paid, and remind "three days before" a date
/// that moves between months. So each item books its *next open* due date's
/// reminders as one-offs, and the whole set is rebuilt on every edit, every
/// tick and every time the app comes forward.
///
/// The risk with one-offs is the app not being opened, so each repeating item
/// also books a **follow-up**: the on-the-day reminder for the occurrence after
/// next. Pay in October without opening the app again and November still
/// reminds you. Follow-ups are booked last, so if the budget is tight it is a
/// safety net that goes, never a reminder that is actually due.
///
/// Nothing is ever silently dropped by iOS, because the total stays inside
/// `NotificationBudget` — and what does not fit is returned, so the screen can
/// say which items will not be reminded rather than leaving you to find out.
public enum DueReminderPlan {
    public static let prefix = "senku.due."

    public struct Result: Equatable, Sendable {
        public var reminders: [PlannedReminder] = []
        /// Items that wanted reminders and got none for lack of room.
        public var unscheduled: [UUID] = []
    }

    /// The most an item can ever book: one per reminder, and the follow-up
    /// if it repeats.
    ///
    /// The worst case rather than today's count — which falls as reminders
    /// pass — so that what fits does not change from one day to the next. A
    /// reminder you were allowed to turn on in the morning is still allowed in
    /// the evening.
    public static func cost(of item: DueItem) -> Int {
        guard !item.remindDaysBefore.isEmpty, !item.isFinished else { return 0 }
        return item.remindDaysBefore.count + (item.repeats == .never ? 0 : 1)
    }

    /// Requests still free, leaving out one item (the one being edited).
    public static func slotsLeft(
        _ items: [DueItem],
        excluding id: UUID? = nil,
        limit: Int = NotificationBudget.allocation(.dueDates)
    ) -> Int {
        limit - items.filter { $0.id != id }.reduce(0) { $0 + cost(of: $1) }
    }

    public static func plan(
        _ items: [DueItem],
        now: Date = .now,
        limit: Int = NotificationBudget.allocation(.dueDates),
        calendar: Calendar = .current,
        amount: (DueItem) -> String? = { _ in nil }
    ) -> Result {
        var primaries: [(item: DueItem, reminders: [PlannedReminder])] = []
        var followUps: [PlannedReminder] = []

        for item in items where !item.remindDaysBefore.isEmpty {
            guard let next = item.nextOpen(calendar: calendar) else { continue }
            let money = amount(item)
            var own: [PlannedReminder] = []

            if next < calendar.startOfDay(for: now) {
                // Overdue: one nudge at the usual time, today if it is still
                // ahead and tomorrow if not. Rebuilt on the next launch, so an
                // unpaid bill keeps asking once a day while the app is used.
                if let fire = nextAtMinute(item.remindAtMinute, after: now, calendar: calendar) {
                    own.append(reminder(item, index: 0, at: fire,
                                        body: "Overdue since \(next.formatted(.dateTime.day().month()))", money))
                }
            } else {
                for (index, fire) in item.reminderDates(for: next, calendar: calendar).enumerated() where fire > now {
                    own.append(reminder(item, index: index, at: fire,
                                        body: phrase(due: next, from: fire, calendar: calendar), money))
                }
            }

            if !own.isEmpty { primaries.append((item, own)) }

            if item.repeats != .never,
               let dayAfter = calendar.date(byAdding: .day, value: 1, to: next),
               let following = item.occurrence(onOrAfter: dayAfter, calendar: calendar),
               let last = item.reminderDates(for: following, calendar: calendar).last,
               last > now {
                followUps.append(reminder(item, index: 9, at: last,
                                          body: phrase(due: following, from: last, calendar: calendar), money))
            }
        }

        var result = Result()

        // Soonest first: when the budget is short, it is the reminder furthest
        // away that waits for the next rebuild, not the one due tomorrow.
        primaries.sort { ($0.reminders.map(\.fireAt).min() ?? .distantFuture) < ($1.reminders.map(\.fireAt).min() ?? .distantFuture) }
        for (item, reminders) in primaries {
            if result.reminders.count + reminders.count <= limit {
                result.reminders += reminders
            } else {
                result.unscheduled.append(item.id)
            }
        }

        let left = Set(result.unscheduled)
        for followUp in followUps.sorted(by: { $0.fireAt < $1.fireAt })
        where result.reminders.count < limit && !left.contains(followUp.itemID) {
            result.reminders.append(followUp)
        }
        return result
    }

    private static func reminder(
        _ item: DueItem,
        index: Int,
        at date: Date,
        body: String,
        _ money: String?
    ) -> PlannedReminder {
        PlannedReminder(
            identifier: "\(prefix)\(item.id.uuidString).\(index)",
            itemID: item.id,
            fireAt: date,
            title: item.title,
            body: [body, money].compactMap { $0 }.joined(separator: " · ")
        )
    }

    /// "Due today", "Due tomorrow", "Due in 3 days — Mon 5 Oct".
    static func phrase(due: Date, from fire: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: fire), to: due).day ?? 0
        switch days {
        case ...0: return "Due today"
        case 1: return "Due tomorrow"
        default: return "Due in \(days) days — \(due.formatted(.dateTime.weekday(.abbreviated).day().month()))"
        }
    }

    private static func nextAtMinute(_ minute: Int, after now: Date, calendar: Calendar) -> Date? {
        let today = calendar.date(byAdding: .minute, value: minute, to: calendar.startOfDay(for: now))
        if let today, today > now { return today }
        return today.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
    }
}
