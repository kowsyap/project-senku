import Foundation
import Observation

/// What the watch list is called — yours to choose.
///
/// The list began as an anime list, and nothing in it is anime-specific: series
/// or film, free-text genres, a status. Someone else's is K-dramas, or films,
/// or everything they watch. So the screen takes the name you give it, and that
/// one name is what the bar, the More list, the sidebar, the title and the
/// report all say.
///
/// Internally it is still `anime` everywhere — the tab, the store, the backup
/// file's key — because renaming those would orphan every list already saved
/// for the sake of a word nobody sees.
@MainActor
@Observable
public final class WatchlistName {
    nonisolated static let storageKey = "senku.watchlist.name.v1"
    public nonisolated static let fallback = "Watchlist"
    public nonisolated static let maxLength = 20

    public static let shared = WatchlistName()

    private let defaults: UserDefaults

    public var name: String {
        didSet {
            let tidy = Self.tidy(name)
            if tidy != name { name = tidy; return }
            defaults.set(name, forKey: Self.storageKey)
        }
    }

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.name = Self.stored(in: defaults)
    }

    /// Never blank: a tab with no name is a tab you cannot find.
    public var title: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? Self.fallback : trimmed
    }

    /// For code off the main actor — the report is drawn there.
    public nonisolated static func current(in defaults: UserDefaults = SenkuStorage.shared) -> String {
        let trimmed = stored(in: defaults).trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private nonisolated static func stored(in defaults: UserDefaults) -> String {
        defaults.string(forKey: storageKey) ?? fallback
    }

    /// Short enough for the bar, which lays every item out at its full width.
    private nonisolated static func tidy(_ text: String) -> String {
        String(text.prefix(maxLength))
    }
}
