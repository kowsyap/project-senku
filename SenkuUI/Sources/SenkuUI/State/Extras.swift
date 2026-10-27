#if !os(watchOS)
import Foundation
import Observation

/// A feature you add or take away in Settings, rather than one the app always
/// carries. Neither has anything to do with training, which is why they are
/// optional.
public enum Extra: String, CaseIterable, Identifiable, Sendable {
    case dues
    case watchlist

    public var id: String { rawValue }

    /// The screen it brings with it.
    public var tab: RootView.Tab {
        switch self {
        case .dues: .dueDates
        case .watchlist: .anime
        }
    }

    public init?(tab: RootView.Tab) {
        guard let extra = Self.allCases.first(where: { $0.tab == tab }) else { return nil }
        self = extra
    }

    /// One line under the name in Settings.
    public var blurb: String {
        switch self {
        case .dues: "Bills and deadlines, with reminders"
        case .watchlist: "Shows and films to keep track of"
        }
    }
}

/// The stores the extras keep their data in, as the app has them open.
@MainActor
struct ExtraData {
    let dues: DueDateStore
    let anime: AnimeStore
}

@MainActor
extension Extra {
    public var title: String { tab.title }

    /// Whether there is anything to lose — with nothing, removing asks once.
    func hasData(in data: ExtraData) -> Bool {
        switch self {
        case .dues: !data.dues.items.isEmpty
        case .watchlist: !data.anime.entries.isEmpty
        }
    }

    /// Everything it holds, written to a file to keep before it is removed.
    ///
    /// In the backup's own shape, holding only this, so Import Data takes it
    /// back like any other backup.
    func export(from data: ExtraData) throws -> URL {
        var document = SenkuImportDocument()
        document.schemaVersion = 1
        switch self {
        case .dues:
            document.dueDates = data.dues.items
        case .watchlist:
            document.anime = data.anime.entries
            document.watchlistScreens = data.anime.screens.isEmpty ? nil : data.anime.screens
        }

        let day = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Senku-\(title)-\(day).json")
        try document.encoded().write(to: url, options: .atomic)
        return url
    }

    /// Its data, gone.
    func erase(in data: ExtraData) {
        switch self {
        case .dues:
            data.dues.eraseAll()
        case .watchlist:
            data.anime.eraseAll()
        }
    }
}

/// Which extras are added.
///
/// Every screen that lists the tabs — the bar, More, the navbar editor, the
/// sidebar, the report — asks here, so an extra that is not added is nowhere.
@MainActor
@Observable
public final class ExtraStore {
    /// v2: v1 held the test extra alone, and read now it would say Dues and
    /// the watchlist had been removed.
    nonisolated static let storageKey = "senku.extras.installed.v2"

    public static let shared = ExtraStore()

    private let defaults: UserDefaults

    public private(set) var installed: Set<Extra>

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.installed = Self.installed(in: defaults)
    }

    public func isInstalled(_ extra: Extra) -> Bool { installed.contains(extra) }

    /// Every screen that is not an extra is always available.
    public func isAvailable(_ tab: RootView.Tab) -> Bool {
        Self.isAvailable(tab, installed: installed)
    }

    public func install(_ extra: Extra) {
        installed.insert(extra)
        persist()
    }

    /// Takes it out and deletes what it held. Saving a copy first is the
    /// caller's to offer.
    func remove(_ extra: Extra, data: ExtraData) {
        extra.erase(in: data)
        installed.remove(extra)
        persist()
    }

    /// After a reset or a restore has rewritten the stored set.
    public func reload() {
        installed = Self.installed(in: defaults)
    }

    /// Nothing stored means nothing has been removed yet: everything is in.
    /// That is every phone from before extras existed, so Dues and the
    /// watchlist stay where they were, and a fresh install starts with both.
    nonisolated static func installed(in defaults: UserDefaults) -> Set<Extra> {
        guard let stored = defaults.array(forKey: storageKey) as? [String] else {
            return Set(Extra.allCases)
        }
        return Set(stored.compactMap(Extra.init(rawValue:)))
    }

    nonisolated static func isAvailable(_ tab: RootView.Tab, installed: Set<Extra>) -> Bool {
        guard let extra = Extra(tab: tab) else { return true }
        return installed.contains(extra)
    }

    private func persist() {
        defaults.set(installed.map(\.rawValue).sorted(), forKey: Self.storageKey)
    }
}
#endif
