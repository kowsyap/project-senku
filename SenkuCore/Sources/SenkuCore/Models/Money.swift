import Foundation

/// A month of a year — what a spend or an income entry is filed under.
///
/// Month and year only, on purpose: money is tracked by the month it belongs
/// to, the way a budget sheet is kept, and asking for the day would be a
/// question with no use behind it.
public struct YearMonth: Codable, Hashable, Comparable, Sendable, Identifiable {
    public let year: Int
    /// 1 to 12.
    public let month: Int

    public init(year: Int, month: Int) {
        // Normalised, so `adding` can overshoot either way.
        let index = year * 12 + (month - 1)
        self.year = Int((Double(index) / 12).rounded(.down))
        self.month = index - self.year * 12 + 1
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month], from: date)
        self.init(year: parts.year ?? 2000, month: parts.month ?? 1)
    }

    public static func current(calendar: Calendar = .current) -> YearMonth {
        YearMonth(.now, calendar: calendar)
    }

    public var id: Int { year * 12 + (month - 1) }

    public func adding(_ months: Int) -> YearMonth {
        YearMonth(year: year, month: month + months)
    }

    /// Months from this one to `other`: positive when `other` is later.
    public func months(to other: YearMonth) -> Int { other.id - id }

    /// Its first day, for charts that plot by date.
    public func firstDay(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    /// Every month from `start` through `end`, oldest first.
    public static func span(_ start: YearMonth, _ end: YearMonth) -> [YearMonth] {
        guard start <= end else { return [] }
        return (0...start.months(to: end)).map { start.adding($0) }
    }

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool { lhs.id < rhs.id }
}

/// One spend, or one income: a name, the month, and the amounts that make
/// it up — several where there were several, like a receipt's items or two
/// paydays in a month.
public struct MoneyEntry: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var month: YearMonth
    /// What it was, or for income where it came from.
    public var name: String
    /// A spend's category. Empty for income, which is grouped by its source.
    public var category: String
    public var amounts: [Double]
    public var note: String

    public init(
        id: UUID = UUID(),
        month: YearMonth,
        name: String,
        category: String = "",
        amounts: [Double],
        note: String = ""
    ) {
        self.id = id
        self.month = month
        self.name = name
        self.category = category
        self.amounts = amounts
        self.note = note
    }

    public var total: Double { amounts.reduce(0, +) }
}

/// The categories a spend starts with. Your own are added beside them.
public enum ExpenseCategory {
    public static let defaults: [String] = [
        "Groceries", "Restaurants", "Coffee & Snacks", "Transport", "Rent", "Utilities",
        "Subscriptions", "Shopping", "Electronics", "Snacks", "Health", "Fitness",
        "Education", "Entertainment", "Personal Care", "Gifts", "Family", "Loan / EMI",
        "Insurance", "Miscellaneous",
    ]

    /// Where a spend goes when its category is taken away.
    public static let fallback = "Miscellaneous"
}

/// How far back the dashboard looks.
public enum MoneyPeriod: Hashable, Sendable {
    case thisMonth
    /// The last n months, this one included.
    case months(Int)
    case thisYear
    case all
    case custom(YearMonth, YearMonth)

    /// The months it covers, given today's month and the earliest with data.
    public func range(now: YearMonth, earliest: YearMonth?) -> ClosedRange<YearMonth> {
        switch self {
        case .thisMonth:
            return now...now
        case .months(let count):
            return now.adding(-(max(count, 1) - 1))...now
        case .thisYear:
            return YearMonth(year: now.year, month: 1)...now
        case .all:
            let start = min(earliest ?? now, now)
            return start...now
        case .custom(let a, let b):
            return min(a, b)...max(a, b)
        }
    }

    /// The same length of time, just before.
    public static func previous(to range: ClosedRange<YearMonth>) -> ClosedRange<YearMonth> {
        let length = range.lowerBound.months(to: range.upperBound) + 1
        return range.lowerBound.adding(-length)...range.lowerBound.adding(-1)
    }
}

/// Everything the dashboard says about a stretch of months.
public struct MoneyReport: Sendable {
    public enum Grouping: Sendable {
        /// Spends, by category.
        case category
        /// Income, by source.
        case name
    }

    public struct Group: Sendable, Identifiable, Equatable {
        public let key: String
        public let total: Double
        /// Of the whole period's total, 0 to 1.
        public let share: Double
        public let count: Int
        public var id: String { key }
    }

    public struct Point: Sendable, Hashable {
        public let month: YearMonth
        public let key: String
        public let total: Double
    }

    public let range: ClosedRange<YearMonth>
    /// Every month in the range, zeros included, oldest first.
    public let monthly: [(month: YearMonth, total: Double, count: Int)]
    public let total: Double
    public let count: Int
    /// Largest first.
    public let groups: [Group]
    /// Largest first, by what they were called.
    public let names: [Group]
    private let entries: [MoneyEntry]
    private let grouping: Grouping

    public init(_ all: [MoneyEntry], range: ClosedRange<YearMonth>, grouping: Grouping, only key: String? = nil) {
        let entries = all.filter {
            range.contains($0.month) && (key == nil || Self.key(of: $0, grouping) == key)
        }
        self.range = range
        self.entries = entries
        self.grouping = grouping
        self.total = entries.reduce(0) { $0 + $1.total }
        self.count = entries.count

        var byMonth: [YearMonth: (Double, Int)] = [:]
        for entry in entries {
            let now = byMonth[entry.month] ?? (0, 0)
            byMonth[entry.month] = (now.0 + entry.total, now.1 + 1)
        }
        self.monthly = YearMonth.span(range.lowerBound, range.upperBound).map {
            ($0, byMonth[$0]?.0 ?? 0, byMonth[$0]?.1 ?? 0)
        }

        let total = self.total
        func grouped(_ key: (MoneyEntry) -> String) -> [Group] {
            var sums: [String: (Double, Int)] = [:]
            for entry in entries {
                let now = sums[key(entry)] ?? (0, 0)
                sums[key(entry)] = (now.0 + entry.total, now.1 + 1)
            }
            return sums
                .map { Group(key: $0.key, total: $0.value.0, share: total > 0 ? $0.value.0 / total : 0, count: $0.value.1) }
                .sorted { $0.total == $1.total ? $0.key < $1.key : $0.total > $1.total }
        }
        self.groups = grouped { Self.key(of: $0, grouping) }
        self.names = grouped(\.name)
    }

    private static func key(of entry: MoneyEntry, _ grouping: Grouping) -> String {
        switch grouping {
        case .category: entry.category.isEmpty ? ExpenseCategory.fallback : entry.category
        case .name: entry.name
        }
    }

    public var monthCount: Int { monthly.count }

    /// Per month, over every month in the range — an empty month counts.
    public var monthlyAverage: Double { monthCount > 0 ? total / Double(monthCount) : 0 }

    /// The month with the most in it, if any has anything.
    public var highestMonth: (month: YearMonth, total: Double)? {
        monthly.filter { $0.total > 0 }.max { $0.total < $1.total }.map { ($0.month, $0.total) }
    }

    /// The fraction this period is up or down on another; nil when the other
    /// had nothing to compare with.
    public func change(from previous: MoneyReport) -> Double? {
        guard previous.total > 0 else { return nil }
        return (total - previous.total) / previous.total
    }

    /// The largest `limit` groups by name, with the rest as "Other".
    public func topGroups(_ limit: Int) -> [Group] {
        guard groups.count > limit else { return groups }
        let kept = Array(groups.prefix(limit))
        let rest = groups.dropFirst(limit)
        let other = rest.reduce(0) { $0 + $1.total }
        return kept + [Group(
            key: Self.other,
            total: other,
            share: total > 0 ? other / total : 0,
            count: rest.reduce(0) { $0 + $1.count }
        )]
    }

    /// Each month's total split by group, the largest `limit` groups by name
    /// and the rest as "Other", for a stacked chart.
    public func stacked(_ limit: Int) -> [Point] {
        let named = Set(groups.prefix(limit).map(\.key))
        var sums: [YearMonth: [String: Double]] = [:]
        for entry in entries {
            let key = Self.key(of: entry, grouping)
            let bucket = named.contains(key) ? key : Self.other
            sums[entry.month, default: [:]][bucket, default: 0] += entry.total
        }
        return sums.keys.sorted().flatMap { month in
            sums[month]!.map { Point(month: month, key: $0.key, total: $0.value) }
                .sorted { $0.key < $1.key }
        }
    }

    /// What a group added up to over each month in the range.
    public func monthlyTotal(of key: String) -> Double {
        groups.first { $0.key == key }.map { $0.total / Double(max(monthCount, 1)) } ?? 0
    }

    public static let other = "Other"
}

/// Names typed before, offered as you type.
public enum MoneySuggestions {
    public struct Suggestion: Sendable, Equatable {
        public let name: String
        /// The category it had the last time it was used.
        public let category: String
    }

    /// Names containing `text`, those starting with it first, then the most
    /// used. Case is ignored in the match and kept as you last typed it.
    public static func matching(_ text: String, in entries: [MoneyEntry], limit: Int = 5) -> [Suggestion] {
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }

        struct Seen { var name: String; var category: String; var count: Int; var latest: YearMonth }
        var seen: [String: Seen] = [:]
        for entry in entries {
            let key = entry.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty, key.contains(query) else { continue }
            if var known = seen[key] {
                known.count += 1
                if entry.month >= known.latest {
                    known.latest = entry.month
                    known.name = entry.name
                    known.category = entry.category
                }
                seen[key] = known
            } else {
                seen[key] = Seen(name: entry.name, category: entry.category, count: 1, latest: entry.month)
            }
        }

        // The exact name already typed is not a suggestion.
        seen.removeValue(forKey: query)

        return seen.sorted { a, b in
            let aStarts = a.key.hasPrefix(query), bStarts = b.key.hasPrefix(query)
            if aStarts != bStarts { return aStarts }
            if a.value.count != b.value.count { return a.value.count > b.value.count }
            return a.value.latest > b.value.latest
        }
        .prefix(limit)
        .map { Suggestion(name: $0.value.name, category: $0.value.category) }
    }
}
