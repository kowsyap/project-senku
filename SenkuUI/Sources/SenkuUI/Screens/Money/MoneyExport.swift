#if !os(watchOS)
import SwiftUI
import SenkuCore

/// What goes into a money CSV: a stretch of months, and the categories (or,
/// for income, the sources) left out. Set from whatever the screen is showing
/// — the dashboard's period and the category picked on it, or the one month
/// open in the list — so Export hands over what you are looking at.
struct MoneyExport {
    var from: YearMonth
    var to: YearMonth
    /// Categories or sources left out. Out rather than in, so one first used
    /// after the sheet opened is not silently dropped.
    var excluded: Set<String> = []

    /// A spend is grouped by its category, income by where it came from.
    static func key(_ entry: MoneyEntry, kind: MoneyStore.Kind) -> String {
        kind == .expenses ? entry.category : entry.name
    }

    /// Every category or source in use, A to Z.
    static func groups(_ entries: [MoneyEntry], kind: MoneyStore.Kind) -> [String] {
        Array(Set(entries.map { key($0, kind: kind) }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func entries(_ all: [MoneyEntry], kind: MoneyStore.Kind) -> [MoneyEntry] {
        let range = min(from, to)...max(from, to)
        return all.filter { range.contains($0.month) && !excluded.contains(Self.key($0, kind: kind)) }
    }

    func csv(_ all: [MoneyEntry], kind: MoneyStore.Kind) -> String {
        var lines = ["Month,Name,\(kind == .expenses ? "Category," : "")Amounts,Total,Note"]
        for entry in entries(all, kind: kind) {
            var fields = [
                "\(entry.month.year)-\(String(format: "%02d", entry.month.month))",
                Self.field(entry.name),
            ]
            if kind == .expenses { fields.append(Self.field(entry.category)) }
            fields.append(Self.field(entry.amounts.map { String(format: "%.2f", $0) }.joined(separator: " + ")))
            fields.append(String(format: "%.2f", entry.total))
            fields.append(Self.field(entry.note))
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// Named for what is in it: "Senku Expenses Nov 2026", "Senku Expenses
    /// Jun–Nov 2026", "Senku Expenses Rent Dec 2025–Nov 2026" when one
    /// category is all that is left in.
    func fileName(_ all: [MoneyEntry], kind: MoneyStore.Kind) -> String {
        var parts = ["Senku", kind.title]
        let left = Self.groups(all, kind: kind).filter { !excluded.contains($0) }
        if left.count == 1, let only = left.first, !only.isEmpty, excluded.count > 0 {
            parts.append(only.replacingOccurrences(of: "/", with: "-"))
        }
        parts.append(Self.months(min(from, to), max(from, to)))
        return parts.joined(separator: " ") + ".csv"
    }

    private static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// "Nov 2026", "Jun–Nov 2026", "Dec 2025–Nov 2026".
    static func months(_ a: YearMonth, _ b: YearMonth) -> String {
        let name = { (m: YearMonth) in monthNames[m.month - 1] }
        if a == b { return "\(name(a)) \(a.year)" }
        if a.year == b.year { return "\(name(a))–\(name(b)) \(b.year)" }
        return "\(name(a)) \(a.year)–\(name(b)) \(b.year)"
    }

    private static func field(_ text: String) -> String {
        guard text.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

#endif
