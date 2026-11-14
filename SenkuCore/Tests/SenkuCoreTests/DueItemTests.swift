import Foundation
import Testing
@testable import SenkuCore

@Suite struct DueItemTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func amex() -> DueItem {
        DueItem(title: "Amex", firstDue: day(2026, 10, 5), repeats: .months)
    }

    @Test func monthlyLandsOnTheSameDay() {
        let item = amex()
        #expect(item.occurrence(0, calendar: calendar) == day(2026, 10, 5))
        #expect(item.occurrence(1, calendar: calendar) == day(2026, 11, 5))
        #expect(item.occurrence(3, calendar: calendar) == day(2027, 1, 5))
    }

    /// Stepping from the first date, not the last, is what keeps the 31st.
    @Test func theThirtyFirstSurvivesFebruary() {
        let item = DueItem(title: "Rent", firstDue: day(2027, 1, 31), repeats: .months)
        #expect(item.occurrence(1, calendar: calendar) == day(2027, 2, 28))
        #expect(item.occurrence(2, calendar: calendar) == day(2027, 3, 31))
    }

    @Test func quarterlyStepsThreeMonths() {
        let item = DueItem(title: "Insurance", firstDue: day(2026, 1, 10), repeats: .months, every: 3)
        #expect(item.occurrence(onOrAfter: day(2026, 5, 1), calendar: calendar) == day(2026, 7, 10))
    }

    @Test func nextOpenIsTheFirstWhenNothingIsDone() {
        #expect(amex().nextOpen(calendar: calendar) == day(2026, 10, 5))
    }

    /// Paying early moves the item on to next month.
    @Test func tickingOffMovesToTheNextOne() {
        var item = amex()
        item.markDone(calendar: calendar)
        #expect(item.doneThrough == day(2026, 10, 5))
        #expect(item.nextOpen(calendar: calendar) == day(2026, 11, 5))
    }

    /// A missed month stays the one that matters until it is ticked.
    @Test func anUnpaidBillStaysOverdue() {
        let item = amex()
        let days = item.daysUntilDue(from: day(2026, 10, 8), calendar: calendar)
        #expect(days == -3)
        #expect(DueState(daysUntilDue: days) == .overdue(days: 3))
    }

    @Test func undoTakesBackTheLastTick() {
        var item = amex()
        item.markDone(calendar: calendar)
        item.markDone(calendar: calendar)
        #expect(item.nextOpen(calendar: calendar) == day(2026, 12, 5))

        item.undoDone(calendar: calendar)
        #expect(item.nextOpen(calendar: calendar) == day(2026, 11, 5))
        item.undoDone(calendar: calendar)
        #expect(item.doneThrough == nil)
    }

    @Test func aOneOffIsFinishedOnceDone() {
        var item = DueItem(title: "Passport", firstDue: day(2027, 3, 1), repeats: .never)
        #expect(item.isFinished == false)
        item.markDone(calendar: calendar)
        #expect(item.nextOpen(calendar: calendar) == nil)
        #expect(DueState(daysUntilDue: item.daysUntilDue(calendar: calendar)) == .finished)
    }

    @Test func aDailyItemYearsOldIsFoundQuickly() {
        let item = DueItem(title: "Pill", firstDue: day(2020, 1, 1), repeats: .days)
        #expect(item.occurrence(onOrAfter: day(2026, 6, 15), calendar: calendar) == day(2026, 6, 15))
    }

    @Test func remindersLandBeforeTheDueDateAtTheirTime() {
        let item = DueItem(
            title: "Amex",
            firstDue: day(2026, 10, 5),
            remindDaysBefore: [0, 3],
            remindAtMinute: 9 * 60 + 30
        )
        let dates = item.reminderDates(for: day(2026, 10, 5), calendar: calendar)
        let expected = [day(2026, 10, 2), day(2026, 10, 5)].map { $0.addingTimeInterval(9.5 * 3600) }
        #expect(dates == expected)
    }

    @Test func phrasesReadNaturally() {
        #expect(DueState(daysUntilDue: 0).phrase == "Due today")
        #expect(DueState(daysUntilDue: 1).phrase == "Tomorrow")
        #expect(DueState(daysUntilDue: 4).phrase == "In 4 days")
        #expect(DueState(daysUntilDue: -1).phrase == "Overdue by a day")
        #expect(amex().repeatSummary == "Every month")
        #expect(DueItem(title: "x", firstDue: .now, repeats: .months, every: 3).repeatSummary == "Every 3 months")
    }

    // MARK: - History and totals

    @Test func tickingWritesTheHistoryWithTodaysAmount() {
        var item = amex()
        item.amount = 1200
        item.markDone(at: day(2026, 10, 3), calendar: calendar)
        item.amount = 1500

        #expect(item.history.count == 1)
        #expect(item.history.first?.due == day(2026, 10, 5))
        #expect(item.history.first?.amount == 1200)
    }

    @Test func undoAlsoTakesTheHistoryLine() {
        var item = amex()
        item.markDone(calendar: calendar)
        item.undoDone(calendar: calendar)
        #expect(item.history.isEmpty)
        #expect(item.doneThrough == nil)
    }

    /// The latest line is an undo; an older one only leaves the log.
    @Test func deletingALogLine() {
        var item = amex()
        item.markDone(calendar: calendar)   // Oct
        item.markDone(calendar: calendar)   // Nov
        let october = item.history[0].id
        let november = item.history[1].id

        item.removeCompletion(october, calendar: calendar)
        #expect(item.history.map(\.id) == [november])
        #expect(item.nextOpen(calendar: calendar) == day(2026, 12, 5))

        item.removeCompletion(november, calendar: calendar)
        #expect(item.history.isEmpty)
        #expect(item.nextOpen(calendar: calendar) == day(2026, 11, 5))
    }

    @Test func openOccurrencesIncludeWhatIsOverdue() {
        let item = DueItem(title: "Gym", firstDue: day(2026, 9, 1), repeats: .weeks)
        let open = item.openOccurrences(through: day(2026, 9, 30), calendar: calendar)
        #expect(open.count == 5)   // 1, 8, 15, 22, 29 Sept
    }

    @Test func theMonthAddsUpWhatIsLeftAndWhatWasPaid() {
        var amex = amex()
        amex.amount = 1200
        var rent = DueItem(title: "Rent", firstDue: day(2026, 10, 1), repeats: .months)
        rent.amount = 20000
        rent.markDone(at: day(2026, 10, 1), calendar: calendar)
        let noAmount = DueItem(title: "Passport", firstDue: day(2026, 10, 20), repeats: .never)

        let totals = DueTotals([amex, rent, noAmount], now: day(2026, 10, 10), calendar: calendar)
        #expect(totals.toPay == 1200)
        #expect(totals.paid == 20000)
        #expect(totals.hasAmounts)
    }

    /// Last month's unpaid bill still needs paying this month.
    @Test func anOverdueBillCountsTowardsThisMonth() {
        var amex = DueItem(title: "Amex", firstDue: day(2026, 9, 5), repeats: .months)
        amex.amount = 1000
        let totals = DueTotals([amex], now: day(2026, 10, 10), calendar: calendar)
        #expect(totals.toPay == 2000)   // September's and October's
    }

    @Test func noAmountsMeansNoTotal() {
        #expect(DueTotals([amex()], now: day(2026, 10, 1), calendar: calendar).hasAmounts == false)
    }

    @Test func anItemSavedBeforeHistoryStillLoads() throws {
        var item = amex()
        item.markDone(calendar: calendar)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as! [String: Any]
        json.removeValue(forKey: "history")
        let decoded = try JSONDecoder().decode(DueItem.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.history.isEmpty)
        #expect(decoded.doneThrough == item.doneThrough)
    }

    @Test func theTotalKnowsWhatIsLateOrDueToday() {
        var late = DueItem(title: "Amex", firstDue: day(2026, 10, 2), repeats: .months)
        late.amount = 1000
        var today = DueItem(title: "Rent", firstDue: day(2026, 10, 10), repeats: .months)
        today.amount = 500
        var later = DueItem(title: "Phone", firstDue: day(2026, 10, 25), repeats: .months)
        later.amount = 50

        let all = DueTotals([late, today, later], now: day(2026, 10, 10), calendar: calendar)
        #expect(all.includesOverdue)
        #expect(all.includesToday)

        let onlyToday = DueTotals([today, later], now: day(2026, 10, 10), calendar: calendar)
        #expect(!onlyToday.includesOverdue)
        #expect(onlyToday.includesToday)

        let neither = DueTotals([later], now: day(2026, 10, 10), calendar: calendar)
        #expect(!neither.includesOverdue && !neither.includesToday)
    }

    @Test func paidDropsOffTheListUntilItsNextWindow() {
        var amex = amex()   // 5 Oct, monthly: a week ahead
        #expect(amex.isOpen(on: day(2026, 9, 28), calendar: calendar))
        #expect(!amex.isOpen(on: day(2026, 9, 27), calendar: calendar))

        amex.markDone(at: day(2026, 10, 3), calendar: calendar)
        #expect(!amex.isOpen(on: day(2026, 10, 10), calendar: calendar))
        #expect(amex.isOpen(on: day(2026, 10, 29), calendar: calendar))   // 5 Nov is a week off
    }

    /// The case the month boundary got wrong: due on the 2nd, on the list in
    /// the last week of the month before rather than on the 1st.
    @Test func aBillEarlyInTheMonthShowsUpTheMonthBefore() {
        let rent = DueItem(title: "Rent", firstDue: day(2026, 12, 2), repeats: .months)
        #expect(rent.isOpen(on: day(2026, 11, 25), calendar: calendar))
        #expect(!rent.isOpen(on: day(2026, 11, 24), calendar: calendar))
    }

    @Test func lastMonthsUnpaidBillIsStillOpen() {
        let late = DueItem(title: "Amex", firstDue: day(2026, 9, 5), repeats: .months)
        #expect(late.isOpen(on: day(2026, 10, 10), calendar: calendar))
    }

    @Test func howFarAheadDependsOnTheRepeat() {
        let start = day(2026, 10, 5)
        #expect(DueItem(title: "", firstDue: start, repeats: .days, remindDaysBefore: [0]).leadDays == 0)
        #expect(DueItem(title: "", firstDue: start, repeats: .weeks, remindDaysBefore: [0]).leadDays == 3)
        #expect(DueItem(title: "", firstDue: start, repeats: .months, remindDaysBefore: [0]).leadDays == 7)
        #expect(DueItem(title: "", firstDue: start, repeats: .years, remindDaysBefore: [0]).leadDays == 30)
        #expect(DueItem(title: "", firstDue: start, repeats: .never, remindDaysBefore: [0]).leadDays == 30)
        // An earlier reminder pulls the window out to meet it.
        #expect(DueItem(title: "", firstDue: start, repeats: .weeks, every: 2, remindDaysBefore: [7, 0]).leadDays == 7)
    }

    @Test func earlyRemindersAreShorterThanTheStep() {
        let start = day(2026, 10, 5)
        #expect(DueItem(title: "", firstDue: start, repeats: .days, every: 3).earlyChoices.isEmpty)
        #expect(DueItem(title: "", firstDue: start, repeats: .days, every: 4).earlyChoices == [1])
        #expect(DueItem(title: "", firstDue: start, repeats: .weeks).earlyChoices == [1, 3])
        #expect(DueItem(title: "", firstDue: start, repeats: .weeks, every: 2).earlyChoices == [1, 3, 7])
        #expect(DueItem(title: "", firstDue: start, repeats: .months).earlyChoices == [1, 3, 7])
    }

    /// What was paid goes in the history; the item stays without an amount.
    @Test func whatWasPaidIsLoggedWithoutSettingAnAmount() {
        var power = DueItem(title: "Electricity", firstDue: day(2026, 10, 5), repeats: .months)
        power.markDone(at: day(2026, 10, 5), paid: 1840, calendar: calendar)
        #expect(power.history.last?.amount == 1840)
        #expect(power.amount == nil)
        #expect(DueTotals([power], now: day(2026, 10, 10), calendar: calendar).paid == 1840)
    }

    @Test func eachStepTopsOutBeforeTheNextUnit() {
        let start = day(2026, 10, 5)
        #expect(DueItem(title: "", firstDue: start, repeats: .weeks, every: 5).every == 3)
        #expect(DueItem(title: "", firstDue: start, repeats: .months, every: 12).every == 11)
        #expect(DueItem(title: "", firstDue: start, repeats: .months, every: 3).every == 3)
        #expect(DueItem(title: "", firstDue: start, repeats: .years, every: 2).every == 1)
    }

    @Test func aDailyStepTopsOutAtSixAndDropsWhatItCannotOffer() {
        var item = DueItem(title: "", firstDue: day(2026, 10, 5), repeats: .days, every: 9, remindDaysBefore: [3, 0])
        #expect(item.every == 6)
        #expect(item.remindDaysBefore == [0])

        item.remindDaysBefore = [7, 0]
        item.repeats = .weeks
        item.every = 1
        item.tidyRepeat()
        #expect(item.remindDaysBefore == [0])
    }

    @Test func anOldItemIsTidiedOnLoad() throws {
        let item = DueItem(title: "Gym", firstDue: day(2026, 10, 5), repeats: .months, remindDaysBefore: [7, 0])
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as! [String: Any]
        json["repeats"] = "days"
        json["every"] = 2
        let decoded = try JSONDecoder().decode(DueItem.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.remindDaysBefore == [0])
    }

    /// The total counts what the list shows: a monthly bill a fortnight out
    /// is not in it yet.
    @Test func theTotalFollowsTheWindow() {
        var phone = DueItem(title: "Phone", firstDue: day(2026, 10, 24), repeats: .months)
        phone.amount = 50
        #expect(DueTotals([phone], now: day(2026, 10, 10), calendar: calendar).toPay == 0)
        #expect(DueTotals([phone], now: day(2026, 10, 17), calendar: calendar).toPay == 50)
    }

    /// A daily item counts today's, not the rest of the month's.
    @Test func aDailyItemCountsOnlyToday() {
        var lunch = DueItem(title: "Lunch", firstDue: day(2026, 10, 10), repeats: .days)
        lunch.amount = 100
        #expect(DueTotals([lunch], now: day(2026, 10, 10), calendar: calendar).toPay == 100)
    }
}
