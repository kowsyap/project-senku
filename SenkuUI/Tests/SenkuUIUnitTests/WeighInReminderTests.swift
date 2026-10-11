import Foundation
import Testing
@testable import SenkuUI

/// The weigh-in reminder rings on the mornings you have not weighed in.
@Suite struct WeighInReminderTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func plan(now: Date, weighed: [Date]) -> [Date] {
        WeighInReminderPlan.mornings(from: now, weighedIn: weighed, hour: 10, count: 7, calendar: calendar)
    }

    @Test func aMorningAlreadyWeighedIsSkipped() {
        let reminders = plan(now: at(11, 7, 30), weighed: [at(11, 7, 15)])
        #expect(!reminders.contains(at(11, 10)))
        #expect(reminders.first == at(12, 10))
    }

    @Test func aMorningNotYetWeighedStillRings() {
        let reminders = plan(now: at(11, 7, 30), weighed: [at(10, 7)])
        #expect(reminders.first == at(11, 10))
        #expect(reminders.count == 7)
    }

    /// Past ten, today is done either way; the week runs from tomorrow.
    @Test func afterTenTodayIsLeftOut() {
        let reminders = plan(now: at(11, 11), weighed: [])
        #expect(reminders.first == at(12, 10))
        #expect(reminders.count == 6)
    }

    /// Deleting this morning's weigh-in puts this morning's reminder back.
    @Test func deletingTheWeighInBringsTheReminderBack() {
        #expect(plan(now: at(11, 8), weighed: []).first == at(11, 10))
    }

    @Test func theBudgetStillAddsUp() {
        #expect(NotificationBudget.allocation(.weighIn) == 7)
        #expect(NotificationBudget.allocated + NotificationBudget.reserve <= NotificationBudget.limit)
    }
}
