import Foundation

/// Where the profile lives.
///
/// A widget runs in its own process and cannot see the app's `UserDefaults`, so
/// anything a widget has to read has to sit in a shared App Group container
/// instead. This is that container.
///
/// The fallback matters: an App Group is a signed entitlement, and it is
/// genuinely absent in previews, in unit tests, and in any build whose signing
/// does not grant it. Falling back to `.standard` keeps the app working in all
/// of those, with the widget simply showing its empty state.
public enum SenkuStorage {
    public static let appGroup = "group.pk.Senku"

    /// `UserDefaults` is not `Sendable`, but it is documented as thread-safe,
    /// and this is a single immutable handle to a process-wide store.
    nonisolated(unsafe) public static let shared: UserDefaults = {
        guard let group = UserDefaults(suiteName: appGroup) else { return .standard }
        migrateIfNeeded(into: group)
        return group
    }()

    /// Whether the shared container was actually available, or the fallback is
    /// in use. Worth being able to ask: a write to `.standard` succeeds, and is
    /// then invisible to every other process — which looks exactly like a write
    /// that never happened.
    public static let isShared: Bool = UserDefaults(suiteName: appGroup) != nil

    /// Moves a profile saved before the App Group existed into it, once.
    ///
    /// Without this, turning on the group would silently look like the user's
    /// profile had been deleted — the data would still be in `.standard`, just
    /// nowhere anything reads any more.
    private static func migrateIfNeeded(into group: UserDefaults) {
        let key = ProfileStore.storageKey
        guard group.data(forKey: key) == nil,
              let existing = UserDefaults.standard.data(forKey: key)
        else { return }

        group.set(existing, forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
    }
}
