import Foundation

/// How often something falls due.
public enum DueRepeat: String, Codable, CaseIterable, Identifiable, Sendable {
    case never
    case days
    case weeks
    case months
    case years

    public var id: String { rawValue }

    /// The longest step before the next unit up says it better: every six
    /// days, then weekly; three weeks, then monthly; eleven months, then
    /// yearly. Yearly has no step — every two years is rare enough to be a
    /// one-off you add again.
    public var maxEvery: Int {
        switch self {
        case .never, .years: 1
        case .days: 6
        case .weeks: 3
        case .months: 11
        }
    }

    var component: Calendar.Component? {
        switch self {
        case .never: nil
        case .days: .day
        case .weeks: .weekOfYear
        case .months: .month
        case .years: .year
        }
    }

    /// "month" / "months", for "Every 3 months".
    public func unit(_ count: Int) -> String {
        let singular: String
        switch self {
        case .never: return ""
        case .days: singular = "day"
        case .weeks: singular = "week"
        case .months: singular = "month"
        case .years: singular = "year"
        }
        return count == 1 ? singular : singular + "s"
    }
}

/// Something that falls due: a card bill on the 5th, insurance every quarter,
/// a passport in 2031, an assignment on Friday.
///
/// ## One date, and everything else follows from it
///
/// An item is a first due date and a step — every 1 month, every 3, every
/// year, or never. Each occurrence is computed from the *first* date rather
/// than from the one before, which is what keeps a bill on the 31st on the 31st:
/// stepping month by month would clamp to the 28th in February and stay there
/// for ever after.
///
/// ## Done, not just reminded
///
/// `doneThrough` is the last occurrence you ticked off. The next one that is
/// not done is what the list shows and what gets reminded — so paying Amex on
/// the 2nd stops the reminder on the 5th, which a calendar alarm cannot do.
public struct DueItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    /// Free text — "Bills", "Subscriptions", "Studies" — so the list groups
    /// the way you think rather than the way the app guessed.
    public var category: String
    /// For a category of your own, whether paying it is logged in Expenses.
    /// The defaults decide for themselves: a loan or a utility always is, a
    /// card bill never.
    public var logsExpense: Bool
    public var amount: Double?
    public var note: String

    /// The first time it is due. Only the day counts; the time is ignored.
    public var firstDue: Date
    public var repeats: DueRepeat
    /// The step: 3 with `.months` is quarterly. At least 1.
    public var every: Int

    /// Days before each due date to be reminded: 0 is on the day itself.
    /// Empty means no reminders — a list you only look at is a fine use.
    public var remindDaysBefore: [Int]
    /// When on the day the reminder lands, in minutes after midnight.
    public var remindAtMinute: Int

    /// The latest occurrence ticked off, if any.
    public var doneThrough: Date?

    /// Every tick, oldest first — what was paid, and when.
    public var history: [DueCompletion]

    public var createdAt: Date

    /// Saved with its days at noon — see `noon(of:)`. Missing from items saved
    /// before, which is how they are found and moved on load.
    private var daysAtNoon = true

    /// The one earlier reminder you can add to "on the day": a day, three, or a
    /// week ahead. One, not several — two warnings for the same bill is one
    /// more than anybody reads.
    public static let earlyReminderChoices = [1, 3, 7]

    /// The categories offered before any of your own.
    public static let defaultCategories = ["Credit Card", "Loan", "Utilities"]

    /// The Expenses category a payment of this goes into: a loan under Loan /
    /// EMI, a utility under Utilities, one of your own under its own name if
    /// you have it logged. Never a card bill — what was bought on the card is
    /// the spending, and logging the bill as well would count it twice — and
    /// never one with no category, which has nowhere to go.
    public var expenseCategory: String? {
        let name = category.trimmingCharacters(in: .whitespaces)
        switch name.lowercased() {
        case "", "credit card": return nil
        case "loan": return "Loan / EMI"
        case "utilities": return "Utilities"
        default: return logsExpense ? name : nil
        }
    }

    /// A category you typed, not one of the defaults.
    public var hasCustomCategory: Bool {
        let name = category.trimmingCharacters(in: .whitespaces)
        return !name.isEmpty && !Self.defaultCategories.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        category: String = "",
        logsExpense: Bool = true,
        amount: Double? = nil,
        note: String = "",
        firstDue: Date,
        repeats: DueRepeat = .months,
        every: Int = 1,
        remindDaysBefore: [Int] = [0],
        remindAtMinute: Int = 9 * 60,
        doneThrough: Date? = nil,
        history: [DueCompletion] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.logsExpense = logsExpense
        self.amount = amount
        self.note = note
        self.firstDue = firstDue
        self.repeats = repeats
        self.every = max(1, every)
        self.remindDaysBefore = Array(Set(remindDaysBefore.filter { $0 >= 0 })).sorted(by: >)
        self.remindAtMinute = min(max(remindAtMinute, 0), 24 * 60 - 1)
        self.doneThrough = doneThrough
        self.history = history
        self.createdAt = createdAt
        tidyRepeat()
    }

    /// Items saved before the history existed come back with an empty one.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        logsExpense = try container.decodeIfPresent(Bool.self, forKey: .logsExpense) ?? true
        amount = try container.decodeIfPresent(Double.self, forKey: .amount)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        firstDue = try container.decode(Date.self, forKey: .firstDue)
        repeats = try container.decodeIfPresent(DueRepeat.self, forKey: .repeats) ?? .never
        every = max(1, try container.decodeIfPresent(Int.self, forKey: .every) ?? 1)
        remindDaysBefore = try container.decodeIfPresent([Int].self, forKey: .remindDaysBefore) ?? []
        remindAtMinute = try container.decodeIfPresent(Int.self, forKey: .remindAtMinute) ?? 9 * 60
        doneThrough = try container.decodeIfPresent(Date.self, forKey: .doneThrough)
        history = try container.decodeIfPresent([DueCompletion].self, forKey: .history) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        if try container.decodeIfPresent(Bool.self, forKey: .daysAtNoon) != true {
            moveDaysToNoon(calendar: .current)
        }
        tidyRepeat()
    }

    // MARK: - Days that survive a change of time zone

    /// Noon on `date`'s day.
    ///
    /// Every day an item keeps — its first date, the last one ticked off, each
    /// one in the history — is kept at noon, not midnight. A saved date is a
    /// moment, and which day a moment falls on depends on where the phone is:
    /// midnight on the 5th in Chicago is still the 4th in Los Angeles, which
    /// reopened a bill ticked off on the 5th. Noon is the same day anywhere
    /// within eleven hours of where it was saved.
    public static func noon(of date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)) ?? date
    }

    /// Moves an item saved before days were kept at noon: its done dates are
    /// midnights wherever they were ticked, and its first date is whatever time
    /// of day it was picked.
    mutating func moveDaysToNoon(calendar: Calendar) {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!

        // A midnight anywhere from UTC−11 to UTC+11 is under twelve hours from
        // the UTC midnight of its own date, so that is the date it meant.
        func day(ofMidnight date: Date) -> DateComponents {
            utc.dateComponents([.year, .month, .day], from: date.addingTimeInterval(12 * 3600))
        }
        func noon(_ day: DateComponents) -> Date? {
            calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))
        }

        // The first date was picked where the first tick was made, and that
        // tick's midnight says how far from UTC it was. With no tick, here.
        let offset: TimeInterval
        if let midnight = history.map(\.due).min() ?? doneThrough,
           let utcMidnight = utc.date(from: day(ofMidnight: midnight)) {
            offset = utcMidnight.timeIntervalSince(midnight)
        } else {
            offset = TimeInterval(calendar.timeZone.secondsFromGMT(for: firstDue))
        }
        let firstDay = utc.dateComponents([.year, .month, .day], from: firstDue.addingTimeInterval(offset))
        if let first = noon(firstDay) { firstDue = first }

        if let done = doneThrough, let moved = noon(day(ofMidnight: done)) { doneThrough = moved }
        for index in history.indices {
            if let moved = noon(day(ofMidnight: history[index].due)) { history[index].due = moved }
        }
        daysAtNoon = true
    }

    // MARK: - Reminders that make sense for the step

    /// The early reminders worth offering: only ones shorter than the gap
    /// between due dates, since "a week before" a weekly bill lands on the
    /// previous one's day and says nothing on-the-day did not.
    ///
    /// Daily gets "a day before" only from every four days, and nothing
    /// longer — three days ahead of something due every five is noise.
    public var earlyChoices: [Int] {
        switch repeats {
        case .days: every >= 4 ? [1] : []
        case .weeks: Self.earlyReminderChoices.filter { $0 < every * 7 }
        case .never, .months, .years: Self.earlyReminderChoices
        }
    }

    /// Keeps the step and the reminders to what the repeat allows: a step no
    /// longer than `maxEvery`, and no early reminder the step does not offer.
    /// Run on every load, so an item saved before the rule is brought into it.
    public mutating func tidyRepeat() {
        every = min(every, repeats.maxEvery)
        let early = earlyChoices
        remindDaysBefore = remindDaysBefore.filter { $0 == 0 || early.contains($0) }
    }

    /// How many days ahead of its date an item joins the to-pay list: on the
    /// day for daily, three days for weekly, a week for monthly, a month for
    /// yearly and one-offs — or the early reminder, if that is earlier, so the
    /// reminder never points at something the list calls paid.
    public var leadDays: Int {
        let base = switch repeats {
        case .days: 0
        case .weeks: 3
        case .months: 7
        case .never, .years: 30
        }
        return max(base, remindDaysBefore.max() ?? 0)
    }

    /// The last day of `now`'s to-pay window.
    public func windowEnd(from now: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: leadDays, to: calendar.startOfDay(for: now))!
    }

    public var isComplete: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Occurrences

    /// The `index`th due date, from zero, at the start of its day.
    public func occurrence(_ index: Int, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: firstDue)
        guard index > 0 else { return index == 0 ? start : nil }
        guard let component = repeats.component else { return nil }
        return calendar.date(byAdding: component, value: index * every, to: start)
    }

    /// The first occurrence on or after `date`'s day.
    public func occurrence(onOrAfter date: Date, calendar: Calendar = .current) -> Date? {
        let day = calendar.startOfDay(for: date)
        guard let first = occurrence(0, calendar: calendar) else { return nil }
        if first >= day { return first }
        guard repeats != .never else { return nil }

        // A jump close to the answer, then a step or two to land on it — so a
        // daily item five years old is not five years of iteration.
        let estimate = estimatedIndex(from: first, to: day, calendar: calendar)
        var index = max(0, estimate - 2)
        while let candidate = occurrence(index, calendar: calendar) {
            if candidate >= day { return candidate }
            index += 1
        }
        return nil
    }

    private func estimatedIndex(from first: Date, to day: Date, calendar: Calendar) -> Int {
        guard let component = repeats.component else { return 0 }
        let elapsed = calendar.dateComponents([component], from: first, to: day)
        let units = elapsed.value(for: component) ?? 0
        return max(0, units / every)
    }

    /// The next due date not yet ticked off — overdue ones included, since an
    /// unpaid bill from last week is the one that matters most.
    ///
    /// Nil when there is nothing left: a one-off that is done.
    public func nextOpen(calendar: Calendar = .current) -> Date? {
        guard let doneThrough else { return occurrence(0, calendar: calendar) }
        let after = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: doneThrough))!
        return occurrence(onOrAfter: after, calendar: calendar)
    }

    /// The one before `date`, for undoing a tick.
    public func occurrence(before date: Date, calendar: Calendar = .current) -> Date? {
        let day = calendar.startOfDay(for: date)
        guard let first = occurrence(0, calendar: calendar), first < day else { return nil }
        var index = max(0, estimatedIndex(from: first, to: day, calendar: calendar) - 2)
        var last = first
        while let candidate = occurrence(index, calendar: calendar), candidate < day {
            last = candidate
            index += 1
        }
        return last
    }

    /// Whether it is on the to-pay list: due within `leadDays` of `now`, or
    /// overdue. A month boundary plays no part — a bill on the 2nd shows up
    /// in the last week of the month before, not the day before it is due.
    public func isOpen(on now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let next = nextOpen(calendar: calendar) else { return false }
        return next <= windowEnd(from: now, calendar: calendar)
    }

    /// Everything finished: a one-off ticked off.
    public var isFinished: Bool { nextOpen() == nil }

    // MARK: - Ticking off

    /// Ticks off the next open due date, and writes it in the history with the
    /// amount as it stands today — so changing the bill's amount next year
    /// does not rewrite what was paid this one. `paid` is what was paid this
    /// time, for an item with no set amount; it goes in the history only.
    public mutating func markDone(at now: Date = .now, paid: Double? = nil, calendar: Calendar = .current) {
        guard let next = nextOpen(calendar: calendar) else { return }
        let day = Self.noon(of: next, calendar: calendar)
        doneThrough = day
        history.append(DueCompletion(due: day, doneAt: now, amount: paid ?? amount))
    }

    /// Takes back the last tick, and its line in the history.
    public mutating func undoDone(calendar: Calendar = .current) {
        guard let doneThrough else { return }
        if let index = history.lastIndex(where: { calendar.isDate($0.due, inSameDayAs: doneThrough) }) {
            history.remove(at: index)
        }
        self.doneThrough = occurrence(before: doneThrough, calendar: calendar).map { Self.noon(of: $0, calendar: calendar) }
    }

    /// Removes one line of the history.
    ///
    /// The latest one is an undo — the due date it ticked off comes back as
    /// open. An older one only leaves the log: the dates after it are still
    /// done, and reopening a bill from March because its record was tidied
    /// away would be a strange thing for a delete to do.
    public mutating func removeCompletion(_ id: UUID, calendar: Calendar = .current) {
        guard let entry = history.first(where: { $0.id == id }) else { return }
        if let doneThrough, calendar.isDate(entry.due, inSameDayAs: doneThrough) {
            undoDone(calendar: calendar)
        } else {
            history.removeAll { $0.id == id }
        }
    }

    /// Every due date still open up to the end of `end`'s day, oldest first —
    /// overdue ones included. Capped, so a daily item left unticked for years
    /// cannot make the list do years of work.
    public func openOccurrences(through end: Date, calendar: Calendar = .current, cap: Int = 400) -> [Date] {
        guard let first = nextOpen(calendar: calendar) else { return [] }
        let last = calendar.startOfDay(for: end)
        var dates: [Date] = []
        var cursor: Date? = first
        while let date = cursor, date <= last, dates.count < cap {
            dates.append(date)
            guard repeats != .never, let after = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            cursor = occurrence(onOrAfter: after, calendar: calendar)
        }
        return dates
    }

    // MARK: - Where it stands

    /// Days from today to the next open due date: negative when overdue.
    public func daysUntilDue(from now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let next = nextOpen(calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: next).day
    }

    /// "Every month", "Every 3 months", "Once".
    public var repeatSummary: String {
        guard repeats != .never else { return "Once" }
        return every == 1 ? "Every \(repeats.unit(1))" : "Every \(every) \(repeats.unit(every))"
    }

    /// When to be reminded about the occurrence on `due`, soonest last.
    public func reminderDates(for due: Date, calendar: Calendar = .current) -> [Date] {
        let day = calendar.startOfDay(for: due)
        return remindDaysBefore.compactMap { before in
            guard let date = calendar.date(byAdding: .day, value: -before, to: day) else { return nil }
            return calendar.date(byAdding: .minute, value: remindAtMinute, to: date)
        }
    }
}

/// How far off something is, in the words the list uses.
public enum DueState: Equatable, Sendable {
    case overdue(days: Int)
    case today
    case soon(days: Int)       // within a week
    case later(days: Int)
    case finished

    public init(daysUntilDue days: Int?) {
        guard let days else { self = .finished; return }
        switch days {
        case ..<0: self = .overdue(days: -days)
        case 0: self = .today
        case 1...7: self = .soon(days: days)
        default: self = .later(days: days)
        }
    }

    /// "Overdue by 2 days", "Due today", "Tomorrow", "In 4 days".
    public var phrase: String {
        switch self {
        case .overdue(let days): days == 1 ? "Overdue by a day" : "Overdue by \(days) days"
        case .today: "Due today"
        case .soon(1): "Tomorrow"
        case .soon(let days), .later(let days): "In \(days) days"
        case .finished: "Done"
        }
    }
}

/// One tick: which due date, when it was done, and what it came to.
public struct DueCompletion: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var due: Date
    public var doneAt: Date
    public var amount: Double?
    /// The spend this payment was logged as in Expenses, if it was — so taking
    /// the tick back takes the spend with it.
    public var expenseID: UUID?

    public init(id: UUID = UUID(), due: Date, doneAt: Date = .now, amount: Double? = nil, expenseID: UUID? = nil) {
        self.id = id
        self.due = due
        self.doneAt = doneAt
        self.amount = amount
        self.expenseID = expenseID
    }
}

/// What is left to pay, and what was paid this month.
///
/// "Left to pay" is every open due date inside each item's to-pay window —
/// the same dates the list shows, overdue ones included, because they have
/// not stopped needing paying. "Paid" is what was ticked off this month,
/// whichever month it was due in. Items without an amount count for neither:
/// the amount is optional, and a total that guessed would be worse than one
/// that says what it knows.
public struct DueTotals: Equatable, Sendable {
    public var toPay: Double = 0
    public var paid: Double = 0
    /// Whether any item has an amount at all — no amounts, no total to show.
    public var hasAmounts = false
    /// Whether any of `toPay` is past its date, or due today — what colours
    /// the total red or orange.
    public var includesOverdue = false
    public var includesToday = false

    public init(_ items: [DueItem], now: Date = .now, calendar: Calendar = .current) {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return }

        for item in items {
            if let amount = item.amount, amount > 0 {
                hasAmounts = true
                let open = item.openOccurrences(through: item.windowEnd(from: now, calendar: calendar), calendar: calendar)
                toPay += amount * Double(open.count)

                let today = calendar.startOfDay(for: now)
                if open.contains(where: { $0 < today }) { includesOverdue = true }
                if open.contains(today) { includesToday = true }
            }
            for entry in item.history where month.contains(entry.doneAt) {
                if let amount = entry.amount, amount > 0 {
                    hasAmounts = true
                    paid += amount
                }
            }
        }
    }
}
