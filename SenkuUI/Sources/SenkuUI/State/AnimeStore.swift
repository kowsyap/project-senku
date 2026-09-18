import Foundation
import Observation
import SenkuCore

/// The anime list, kept like everything else: JSON in the App Group.
@Observable
public final class AnimeStore {
    static let storageKey = "senku.anime.v1"

    private let defaults: UserDefaults

    public private(set) var entries: [AnimeEntry] = []

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.entries = Self.load(from: defaults)
    }

    /// Every genre in use, for the filter row — the list is whatever you have
    /// typed rather than a fixed taxonomy, because nobody agrees on one.
    public var genres: [String] {
        Array(Set(entries.flatMap(\.genres))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public func entry(_ id: UUID) -> AnimeEntry? {
        entries.first { $0.id == id }
    }

    public func save(_ entry: AnimeEntry) {
        var entry = entry
        entry.updatedAt = .now

        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        persist()
    }

    public func delete(_ entry: AnimeEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    /// Changing only the status, which is the edit made most often and the one
    /// worth not opening a form for.
    public func setStatus(_ status: AnimeStatus, for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].status = status
        entries[index].updatedAt = .now
        persist()
    }

    public func restore(_ entry: AnimeEntry) {
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        persist()
    }

    /// Searched, filtered and sorted — the list as the screen shows it.
    public func list(
        search: String = "",
        status: AnimeStatus? = nil,
        sort: AnimeSort = .status
    ) -> [AnimeEntry] {
        let filtered = entries.filter { entry in
            entry.matches(search) && (status == nil || entry.status == status)
        }
        return sort.sort(filtered)
    }

    /// What the whole list adds up to, for the header.
    public var totals: AnimeTotals { AnimeTotals(entries) }

    public func count(_ status: AnimeStatus) -> Int {
        entries.filter { $0.status == status }.count
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [AnimeEntry] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AnimeEntry].self, from: data)
        else { return [] }
        return decoded
    }
}
