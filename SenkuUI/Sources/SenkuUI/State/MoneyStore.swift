import Foundation
import Observation
import SenkuCore

/// Spends, or income: entries filed by month, kept like everything else as
/// JSON in the App Group. The two are separate extras with a store each; they
/// share this shape because an income entry is a spend's mirror — a name, a
/// month and some amounts.
@Observable
public final class MoneyStore {
    public enum Kind: String, Sendable {
        case expenses
        case income
    }

    public let kind: Kind
    private let defaults: UserDefaults

    /// Newest month first; within a month, the latest added first.
    public private(set) var entries: [MoneyEntry] = []
    /// Categories added beside the built-in ones. Spends only.
    public private(set) var customCategories: [String] = []

    public init(_ kind: Kind, defaults: UserDefaults = SenkuStorage.shared) {
        self.kind = kind
        self.defaults = defaults
        reload()
    }

    var storageKey: String { "senku.\(kind.rawValue).v1" }
    static let categoriesKey = "senku.expenses.categories.v1"

    public var grouping: MoneyReport.Grouping { kind == .expenses ? .category : .name }

    /// Built-in first, in their order, then your own.
    public var categories: [String] {
        ExpenseCategory.defaults + customCategories
    }

    public func entry(_ id: UUID) -> MoneyEntry? {
        entries.first { $0.id == id }
    }

    public func entries(in month: YearMonth) -> [MoneyEntry] {
        entries.filter { $0.month == month }
    }

    /// The earliest month with anything in it.
    public var earliest: YearMonth? { entries.map(\.month).min() }

    public func save(_ entry: MoneyEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.insert(entry, at: 0)
        }
        sort()
        persist()
    }

    public func delete(_ entry: MoneyEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    /// From a backup: kept if it is not already here.
    @discardableResult
    public func restore(_ entry: MoneyEntry) -> Bool {
        guard !entries.contains(where: { $0.id == entry.id }) else { return false }
        entries.append(entry)
        sort()
        persist()
        return true
    }

    public func suggestions(for text: String) -> [MoneySuggestions.Suggestion] {
        MoneySuggestions.matching(text, in: entries)
    }

    /// A category of your own. Nothing happens for one that already exists,
    /// whatever its capitals.
    @discardableResult
    public func addCategory(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = categories.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        customCategories.append(trimmed)
        persistCategories()
        return trimmed
    }

    /// One of your own, gone; its spends move to Miscellaneous.
    public func removeCategory(_ name: String) {
        guard customCategories.contains(name) else { return }
        customCategories.removeAll { $0 == name }
        for index in entries.indices where entries[index].category == name {
            entries[index].category = ExpenseCategory.fallback
        }
        persistCategories()
        persist()
    }

    /// Everything, gone — the extra removed in Settings.
    public func eraseAll() {
        entries = []
        customCategories = []
        persist()
        persistCategories()
    }

    public func reload() {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MoneyEntry].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }
        sort()
        customCategories = kind == .expenses ? (defaults.stringArray(forKey: Self.categoriesKey) ?? []) : []
    }

    /// Your categories from a backup, joined to what is here.
    public func restoreCategories(_ names: [String]) {
        for name in names { addCategory(name) }
    }

    private func sort() {
        // Stable within a month, so the order things were added in holds.
        entries = entries.enumerated()
            .sorted { $0.element.month == $1.element.month ? $0.offset < $1.offset : $0.element.month > $1.element.month }
            .map(\.element)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func persistCategories() {
        guard kind == .expenses else { return }
        defaults.set(customCategories, forKey: Self.categoriesKey)
    }
}
