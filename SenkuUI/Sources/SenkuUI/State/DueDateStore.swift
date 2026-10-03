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

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.items = Self.load(from: defaults)
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

    public func markDone(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].markDone()
        persist()
    }

    public func undoDone(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].undoDone()
        persist()
    }

    /// Deletes one line of an item's history — see `DueItem.removeCompletion`
    /// for why the latest line is an undo and an older one is not.
    public func removeCompletion(_ completionID: UUID, from itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].removeCompletion(completionID)
        persist()
    }

    /// Every tick across every item, newest first, with what it belonged to.
    public var log: [(item: DueItem, entry: DueCompletion)] {
        items
            .flatMap { item in item.history.map { (item: item, entry: $0) } }
            .sorted { $0.entry.doneAt > $1.entry.doneAt }
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
