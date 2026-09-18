import Foundation

/// A run of days something was done.
///
/// Written once and kept general — a set of days in, three figures out — because
/// the app already has two of these (water, creatine) and will have more the
/// moment calories are logged. The alternative was the same backwards walk
/// copied into each store, which is how two of them end up disagreeing about
/// what a streak is.
public struct Streak: Hashable, Sendable {
    /// The run ending today, or yesterday if today has not been done yet.
    public let current: Int
    /// The longest run anywhere in the days given.
    public let longest: Int
    /// How many of the days in the window were done at all.
    public let total: Int

    public init(current: Int, longest: Int, total: Int) {
        self.current = current
        self.longest = longest
        self.total = total
    }

    /// Works out all three from a set of start-of-day dates.
    ///
    /// Today missing does **not** break the current run. It is often only
    /// mid-afternoon, and a counter that reset every morning and had to be
    /// re-earned by dinner would be wrong about most of the day — so the walk
    /// starts at today when today is done, and at yesterday when it is not.
    public static func of(
        _ days: Set<Date>,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> Streak {
        let today = calendar.startOfDay(for: date)
        let marked = Set(days.map { calendar.startOfDay(for: $0) })

        var current = 0
        var cursor = marked.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today

        while marked.contains(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        var longest = 0
        var run = 0
        for day in marked.sorted() {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: day)
            run = (yesterday.map(marked.contains) ?? false) ? run + 1 : 1
            longest = max(longest, run)
        }

        return Streak(current: current, longest: longest, total: marked.count)
    }
}
