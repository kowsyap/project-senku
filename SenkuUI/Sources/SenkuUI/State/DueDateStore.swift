import Foundation
import Observation
import SenkuCore

/// Bills, renewals and deadlines, kept like everything else: JSON in the App
/// Group.
@Observable
public final class DueDateStore {
    static let storageKey = "senku.due.v1"

    private let defaults: UserDefaults

    public private(set) var items: [DueItem] = []

    /// Where a paid due is logged as a spend. Nil when Expenses is not added,
    /// and then nothing is logged.
    public var expenses: MoneyStore?

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.items = Self.load(from: defaults)
        // Written back once when loading moved anything — items saved before
        // their days were kept at noon — so the move is not redone each launch
        // in whatever time zone the phone is in by then.
        // Never when nothing loaded: a file that failed to read is not overwritten.
        if !items.isEmpty, let saved = defaults.data(forKey: Self.storageKey),
           let current = try? JSONEncoder().encode(items), current != saved {
            persist()
        }
    }

    public func item(_ id: UUID) -> DueItem? {
        items.first { $0.id == id }
    }

    /// Every category in use, for the editor's suggestions.
    public var categories: [String] {
        Array(Set(items.map(\.category).filter { !$0.isEmpty }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public func save(_ item: DueItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            // A tick taken back in the editor takes its spend with it.
            let kept = Set(item.history.map(\.id))
            unlog(items[index].history.filter { !kept.contains($0.id) })
            items[index] = item
        } else {
            items.append(item)
        }
        persist()
    }

    public func delete(_ item: DueItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    public func markDone(_ id: UUID, paid: Double? = nil, at now: Date = .now) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].markDone(at: now, paid: paid)
        log(index, at: now)
        persist()
    }

    public func undoDone(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let before = items[index].history
        items[index].undoDone()
        let kept = Set(items[index].history.map(\.id))
        unlog(before.filter { !kept.contains($0.id) })
        persist()
    }

    /// A payment, logged in Expenses in the month it was paid, with the month
    /// it was for as the note — see `DueItem.expenseCategory` for which are.
    /// Only with an amount: a spend of nothing is not worth a line. A category
    /// of your own is added to Expenses' categories if it is not one already.
    private func log(_ index: Int, at now: Date) {
        guard let expenses, let named = items[index].expenseCategory,
              let category = expenses.addCategory(named),
              let last = items[index].history.indices.last,
              let amount = items[index].history[last].amount, amount > 0
        else { return }
        let due = items[index].history[last].due
        let entry = MoneyEntry(
            month: YearMonth(now),
            name: items[index].title,
            category: category,
            amounts: [amount],
            note: due.formatted(.dateTime.month(.wide))
        )
        expenses.save(entry)
        items[index].history[last].expenseID = entry.id
    }

    /// Takes the spends of ticks that were taken back out of Expenses.
    private func unlog(_ completions: [DueCompletion]) {
        guard let expenses else { return }
        for id in completions.compactMap(\.expenseID) {
            if let entry = expenses.entry(id) { expenses.delete(entry) }
        }
    }

    /// Deletes one line of an item's history — see `DueItem.removeCompletion`
    /// for why the latest line is an undo and an older one is not.
    public func removeCompletion(_ completionID: UUID, from itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        unlog(items[index].history.filter { $0.id == completionID })
        items[index].removeCompletion(completionID)
        persist()
    }

    /// Every tick across every item, newest first, with what it belonged to.
    public var log: [(item: DueItem, entry: DueCompletion)] {
        items
            .flatMap { item in item.history.map { (item: item, entry: $0) } }
            .sorted { $0.entry.doneAt > $1.entry.doneAt }
    }

    /// Every item, gone — Dues removed in Settings. The reminders follow,
    /// because the app reschedules whenever the items change.
    public func eraseAll() {
        items = []
        persist()
    }

    public func restore(_ item: DueItem) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
        persist()
    }

    /// Soonest first — overdue at the top, since a negative count of days is
    /// the smallest — and anything finished at the bottom.
    public var sorted: [DueItem] {
        items.sorted { left, right in
            switch (left.nextOpen(), right.nextOpen()) {
            case let (l?, r?): l == r ? left.title < right.title : l < r
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): left.title < right.title
            }
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [DueItem] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([DueItem].self, from: data)
        else { return [] }
        return decoded
    }
}
