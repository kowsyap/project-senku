import Foundation
import Observation
import SenkuCore

/// The watchlist, kept like everything else: JSON in the App Group.
///
/// Optionally split into collections — Anime, Hollywood, Marvel — each showing
/// the titles in it. With none, it is one list.
///
/// Called screens in the code, which is what they were first called.
@Observable
public final class AnimeStore {
    static let storageKey = "senku.anime.v1"
    static let screensKey = "senku.anime.screens.v1"

    private let defaults: UserDefaults

    public private(set) var entries: [AnimeEntry] = []
    public private(set) var screens: [WatchScreen] = []

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.entries = Self.load(from: defaults)
        self.screens = Self.loadScreens(from: defaults)
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

    /// Every entry and screen, gone — the watchlist removed in Settings.
    public func eraseAll() {
        entries = []
        screens = []
        persist()
        persistScreens()
    }

    public func restore(_ entry: AnimeEntry) {
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        persist()
    }

    // MARK: - Screens

    public func screen(_ id: UUID?) -> WatchScreen? {
        if id == WatchScreen.other.id { return hasOther ? .other : nil }
        return screens.first { $0.id == id }
    }

    /// Whether "Other" has anything to show: titles in no collection, while
    /// there are collections.
    public var hasOther: Bool {
        !screens.isEmpty && entries.contains { $0.screens.isEmpty }
    }

    /// What the title's dropdown offers: the collections, then Other when it
    /// has something in it.
    public var choices: [WatchScreen] {
        hasOther ? screens + [.other] : screens
    }

    /// A new screen. The first one takes every title already on the list:
    /// until now there was one list, and it was that.
    @discardableResult
    public func addScreen(_ name: String) -> WatchScreen? {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        let screen = WatchScreen(name: name)
        if screens.isEmpty {
            for index in entries.indices where entries[index].screens.isEmpty {
                entries[index].screens = [screen.id]
            }
            persist()
        }
        screens.append(screen)
        persistScreens()
        return screen
    }

    public func renameScreen(_ id: UUID, to name: String) {
        guard let index = screens.firstIndex(where: { $0.id == id }) else { return }
        screens[index].name = name
        persistScreens()
    }

    /// Gone, and no title with it: one in no other collection lands in
    /// Other. Deleting the last collection makes it one list again.
    public func deleteScreen(_ id: UUID) {
        screens.removeAll { $0.id == id }

        for index in entries.indices where entries[index].screens.contains(id) {
            entries[index].screens.removeAll { $0 == id }
        }
        if screens.isEmpty {
            for index in entries.indices { entries[index].screens = [] }
        }
        persist()
        persistScreens()
    }

    public func moveScreens(from offsets: IndexSet, to destination: Int) {
        screens.move(fromOffsets: offsets, toOffset: destination)
        persistScreens()
    }

    /// From a backup: added if it is not here already.
    public func restore(_ screen: WatchScreen) {
        guard !screens.contains(where: { $0.id == screen.id }) else { return }
        screens.append(screen)
        persistScreens()
    }

    // MARK: - Reading

    /// Searched, filtered and sorted — the list as the screen shows it.
    public func list(
        search: String = "",
        status: AnimeStatus? = nil,
        screen: UUID? = nil,
        sort: AnimeSort = .status,
        reversed: Bool = false
    ) -> [AnimeEntry] {
        let filtered = entries.filter { entry in
            entry.isOn(screen) && entry.matches(search) && (status == nil || entry.status == status)
        }
        return sort.sort(filtered, reversed: reversed)
    }

    /// What a screen adds up to, for the header.
    public func totals(on screen: UUID? = nil) -> AnimeTotals {
        AnimeTotals(entries.filter { $0.isOn(screen) })
    }

    public func count(_ status: AnimeStatus? = nil, on screen: UUID? = nil) -> Int {
        entries.filter { $0.isOn(screen) && (status == nil || $0.status == status) }.count
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func persistScreens() {
        guard let data = try? JSONEncoder().encode(screens) else { return }
        defaults.set(data, forKey: Self.screensKey)
    }

    private static func load(from defaults: UserDefaults) -> [AnimeEntry] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AnimeEntry].self, from: data)
        else { return [] }
        return decoded
    }

    private static func loadScreens(from defaults: UserDefaults) -> [WatchScreen] {
        guard let data = defaults.data(forKey: screensKey),
              let decoded = try? JSONDecoder().decode([WatchScreen].self, from: data)
        else { return [] }
        return decoded
    }
}
