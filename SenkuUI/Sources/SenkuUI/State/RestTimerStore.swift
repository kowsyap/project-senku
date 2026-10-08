import Foundation
import SenkuCore
#if canImport(WidgetKit)
import WidgetKit
#endif

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
/// Whether logging a set starts a rest, and for how long.
///
/// On by default: resting is what follows every set, and starting the timer
/// by hand each time was the tap this exists to save. A length of its own
/// rather than the Rest tab's last one, so a rest started by hand for a heavy
/// single does not leave every accessory set after it resting for five
/// minutes.
public struct RestAfterSet: Codable, Equatable, Sendable {
    public var isOn = true
    public var seconds: TimeInterval = RestPreset.ninetySeconds.duration

    public init(isOn: Bool = true, seconds: TimeInterval = RestPreset.ninetySeconds.duration) {
        self.isOn = isOn
        self.seconds = seconds
    }

    static let key = "senku.restAfterSet.v1"

    public static func load(from defaults: UserDefaults = SenkuStorage.shared) -> RestAfterSet {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(RestAfterSet.self, from: data)
        else { return RestAfterSet() }
        return decoded
    }

    public func save(to defaults: UserDefaults = SenkuStorage.shared) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

public enum RestTimerStore {
    static let key = "senku.restTimer.v1"
    static let lastDurationKey = "senku.restTimer.lastDuration.v1"

    /// The interval last rested for. Kept apart from the running rest, which
    /// is cleared when it ends — and with it, until now, the only record of
    /// how long you like to rest.
    public static func lastDuration(from defaults: UserDefaults = SenkuStorage.shared) -> TimeInterval? {
        let stored = defaults.double(forKey: lastDurationKey)
        return stored > 0 ? stored : nil
    }

    /// Starts a rest at the interval last used — the Rest tab's own timer,
    /// started from wherever this is called: Control Center, or logging a set.
    ///
    /// Everything a rest started on the Rest tab gets, it gets here: saved for
    /// the tab to pick up, the Live Activity, the chime that sounds on a locked
    /// and silenced phone, and the notification. Then the tab is told, so one
    /// already mounted shows the countdown rather than waiting to reappear.
    @MainActor
    @discardableResult
    public static func startAtLastInterval(at now: Date = .now, defaults: UserDefaults = SenkuStorage.shared) -> RestTimer {
        let interval = lastDuration(from: defaults) ?? load(from: defaults)?.duration ?? RestPreset.ninetySeconds.duration
        return start(seconds: interval, at: now, defaults: defaults)
    }

    /// Starts a rest of a given length, everywhere a rest shows — see
    /// ``startAtLastInterval(at:defaults:)``.
    @MainActor
    @discardableResult
    public static func start(seconds: TimeInterval, at now: Date = .now, defaults: UserDefaults = SenkuStorage.shared) -> RestTimer {
        var timer = (try? RestTimer(duration: seconds)) ?? RestTimer(preset: .ninetySeconds)
        timer.start(at: now)
        save(timer, to: defaults)
        #if os(iOS)
        RestActivityController.shared.sync(with: timer)
        RestChime.sync(with: timer)
        #endif
        #if canImport(UserNotifications) && !os(macOS)
        RestNotifications.sync(with: timer)
        #endif
        RestDeepLink.notifyStarted()
        return timer
    }

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
        defaults.set(timer.duration, forKey: lastDurationKey)
        reloadWidgets()
    }

    public static func clear(from defaults: UserDefaults = SenkuStorage.shared) {
        defaults.removeObject(forKey: key)
        reloadWidgets()
    }

    /// The widget shows a countdown for as long as there is one to show, so a
    /// rest that starts, ends or is reset is exactly when it needs redrawing.
    /// Only reaches the widget on a build with the App Group; harmless without.
    private static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
