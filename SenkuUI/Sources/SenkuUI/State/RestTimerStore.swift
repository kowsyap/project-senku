import Foundation
import SenkuCore

/// The running rest, persisted to the shared App Group.
///
/// Two things need this. A rest started from Control Center happens in another
/// process entirely, and the app has to find it on launch. And a timer held
/// only in `@State` is lost if iOS reclaims the app mid-rest — which looked
/// especially wrong once the Live Activity kept counting on the lock screen
/// after the app itself had forgotten.
///
/// `RestTimer` is `Codable` and holds an absolute deadline, so a stored one is
/// still correct whenever it is read back. Nothing here has to be refreshed.
public enum RestTimerStore {
    static let key = "senku.restTimer.v1"

    public static func load(from defaults: UserDefaults = SenkuStorage.shared) -> RestTimer? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RestTimer.self, from: data)
    }

    public static func save(_ timer: RestTimer, to defaults: UserDefaults = SenkuStorage.shared) {
        // An idle timer is the absence of a rest, not a rest worth restoring.
        guard !timer.isIdle else {
            clear(from: defaults)
            return
        }
        guard let data = try? JSONEncoder().encode(timer) else { return }
        defaults.set(data, forKey: key)
    }

    public static func clear(from defaults: UserDefaults = SenkuStorage.shared) {
        defaults.removeObject(forKey: key)
    }
}
