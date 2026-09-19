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
    /// Days that neither count nor break the run.
    ///
    /// ## Why forgiveness is not the same as success
    ///
    /// A day you forgot to log is not a day you failed, and it is not a day you
    /// succeeded either — it is a day with no information in it. Counting it as
    /// kept would be the app inventing a fact about you; counting it as missed
    /// throws away a real streak because of a flat phone battery. So a forgiven
    /// day is stepped over: the run continues through it, and `total` does not
    /// include it, because `total` is a count of days actually done.
    ///
    /// This is the one thing a past day allows. The calendar stays read-only in
    /// every other respect — a history you can edit is a history that can be
    /// made to say anything, and a streak is only worth looking at if it
    /// records what happened.
    public static func of(
        _ days: Set<Date>,
        forgiven: Set<Date> = [],
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> Streak {
        let today = calendar.startOfDay(for: date)
        let marked = Set(days.map { calendar.startOfDay(for: $0) })
        // A day cannot be both: doing it says more than forgetting it.
        let excused = Set(forgiven.map { calendar.startOfDay(for: $0) }).subtracting(marked)

        var current = 0
        var cursor = marked.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today

        // Skip back over any forgiven days at the start, so a run that ends in
        // one is still the run it was.
        while excused.contains(cursor) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        while marked.contains(cursor) || excused.contains(cursor) {
            if marked.contains(cursor) { current += 1 }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        var longest = 0
        var run = 0
        for day in marked.union(excused).sorted() {
            var yesterday = calendar.date(byAdding: .day, value: -1, to: day)
            // Yesterday counts as continuous if it was done, or forgiven — and
            // through a stretch of forgiven days, however long.
            while let previous = yesterday, excused.contains(previous) {
                yesterday = calendar.date(byAdding: .day, value: -1, to: previous)
            }

            let continuous = yesterday.map { marked.contains($0) || excused.contains($0) } ?? false
            run = continuous ? run + (marked.contains(day) ? 1 : 0) : (marked.contains(day) ? 1 : 0)
            longest = max(longest, run)
        }

        return Streak(current: current, longest: longest, total: marked.count)
    }
}
