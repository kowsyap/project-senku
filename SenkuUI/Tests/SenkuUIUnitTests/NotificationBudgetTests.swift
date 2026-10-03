import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// The 64, added up — the check the old doc comment could not do.
@Suite struct NotificationBudgetTests {
    @Test func everythingFitsUnderTheSystemLimit() {
        #expect(NotificationBudget.allocated + NotificationBudget.reserve <= NotificationBudget.limit)
    }

    @Test func theAllocationIsWhatWasAgreed() {
        #expect(NotificationBudget.allocation(.water) == 12)
        #expect(NotificationBudget.allocation(.rest) == 2)
        #expect(NotificationBudget.allocation(.weighIn) == 1)
        #expect(NotificationBudget.allocation(.creatine) == 1)
        #expect(NotificationBudget.allocation(.dueDates) == 42)
    }
}

@Suite struct DueReminderPlanTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func at(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func amex(remind: [Int] = [3, 0]) -> DueItem {
        DueItem(title: "Amex", firstDue: at(10, 5, 0), repeats: .months, remindDaysBefore: remind)
    }

    @Test func booksEachReminderPlusAFollowUp() {
        let plan = DueReminderPlan.plan([amex()], now: at(10, 1), calendar: calendar)
        let dates = plan.reminders.map(\.fireAt)

        // 2 Oct and 5 Oct at nine, then 5 Nov as the safety net.
        #expect(dates == [
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 9))!,
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 9))!,
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 9))!,
        ])
        #expect(plan.reminders.first?.body.hasPrefix("Due in 3 days") == true)
    }

    /// Paid on the 2nd: the 5th stays quiet and November takes over.
    @Test func aTickedBillIsNotReminded() {
        var item = amex()
        item.markDone(calendar: calendar)
        let plan = DueReminderPlan.plan([item], now: at(10, 2), calendar: calendar)

        #expect(plan.reminders.allSatisfy { $0.fireAt > at(10, 31) })
    }

    @Test func remindersAlreadyPastAreSkipped() {
        let plan = DueReminderPlan.plan([amex()], now: at(10, 3), calendar: calendar)
        #expect(plan.reminders.map(\.fireAt).allSatisfy { $0 > at(10, 3) })
        #expect(plan.reminders.count == 2)   // on the day, and the follow-up
    }

    @Test func anOverdueBillGetsOneNudge() {
        let plan = DueReminderPlan.plan([amex()], now: at(10, 8), calendar: calendar)
        let overdue = plan.reminders.filter { $0.body.hasPrefix("Overdue") }

        #expect(overdue.count == 1)
        // Noon is past nine, so it is tomorrow's nine o'clock.
        #expect(overdue.first?.fireAt == calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 9)))
    }

    @Test func noRemindersMeansNoRequests() {
        let plan = DueReminderPlan.plan([amex(remind: [])], now: at(10, 1), calendar: calendar)
        #expect(plan.reminders.isEmpty)
    }

    /// What does not fit is named, never silently lost — and follow-ups give
    /// way before anything actually due.
    @Test func neverExceedsTheLimit() {
        let items = (0..<30).map { index in
            DueItem(
                title: "Bill \(index)",
                firstDue: at(10, 5 + index % 20, 0),
                repeats: .months,
                remindDaysBefore: [3, 0]
            )
        }
        let plan = DueReminderPlan.plan(items, now: at(10, 1), limit: 42, calendar: calendar)

        #expect(plan.reminders.count <= 42)
        #expect(plan.unscheduled.count == 9)   // 21 items × 2 = 42; nine left
        #expect(Set(plan.reminders.map(\.identifier)).count == plan.reminders.count)
    }

    @Test func theAmountRidesAlong() {
        var item = amex(remind: [0])
        item.amount = 1200
        let plan = DueReminderPlan.plan([item], now: at(10, 1), calendar: calendar, amount: { _ in "$1,200" })
        #expect(plan.reminders.first?.body == "Due today · $1,200")
    }

    @Test func costIsEachReminderPlusTheFollowUp() {
        #expect(DueReminderPlan.cost(of: amex(remind: [3, 0])) == 3)
        #expect(DueReminderPlan.cost(of: amex(remind: [])) == 0)

        let once = DueItem(title: "Passport", firstDue: at(12, 1), repeats: .never, remindDaysBefore: [7, 0])
        #expect(DueReminderPlan.cost(of: once) == 2)
    }

    /// Booking to the worst case means planning never has to leave one out.
    @Test func whatTheCostAllowsAlwaysFits() {
        var items: [DueItem] = []
        while DueReminderPlan.slotsLeft(items) >= 3 {
            items.append(DueItem(title: "Bill", firstDue: at(10, 5, 0), repeats: .months, remindDaysBefore: [3, 0]))
        }
        let plan = DueReminderPlan.plan(items, now: at(10, 1), calendar: calendar)
        #expect(plan.unscheduled.isEmpty)
        #expect(plan.reminders.count <= NotificationBudget.allocation(.dueDates))
    }

    @Test func slotsLeftLeavesOutTheItemBeingEdited() {
        let item = amex()
        #expect(DueReminderPlan.slotsLeft([item]) == 39)
        #expect(DueReminderPlan.slotsLeft([item], excluding: item.id) == 42)
    }
}
