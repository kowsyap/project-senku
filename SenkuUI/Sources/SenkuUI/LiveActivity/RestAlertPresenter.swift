import Foundation

#if canImport(UserNotifications) && !os(macOS)
import UserNotifications
#if os(watchOS)
import WatchKit
#elseif os(iOS)
import UIKit
#endif

/// Lets the end-of-rest alert through while Senku is the app on screen.
///
/// ## The silence this exists to fix
///
/// A notification whose time arrives while its own app is frontmost is handed
/// to the app instead of being shown, and is dropped unless a delegate says
/// otherwise. That default is right for most apps and exactly wrong for this
/// one — and on the watch it is not an edge case but the *normal* path: the
/// extended runtime session that keeps the timer counting also keeps Senku in
/// front, so the rest ends with the app on screen every time. The alert was
/// being scheduled correctly, delivered correctly, and then suppressed for
/// being too successful.
///
/// Returning `.sound` here is what makes the watch ring rather than merely
/// light up. `.banner` and `.list` are asked for as well so a rest that lands
/// while you are on another page of the app still says so.
///
/// Installed once, from the app's initialiser, before any rest can be
/// scheduled.
@MainActor
final class RestAlertPresenter: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    static let shared = RestAlertPresenter()

    private override init() { super.init() }

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// "Log a glass", tapped on a water reminder.
    ///
    /// The action carries no `.foreground` option, so iOS wakes the app in the
    /// background to run this and never brings it to the screen — which is the
    /// whole point: the common case is one tap from the lock screen while
    /// walking away from a tap.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == WaterReminders.logActionID else { return }

        let store = WaterStore()
        let container = store.settings.containers.first
        store.add(millilitres: container?.millilitres ?? 250, container: container)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // On the watch the notification *is* the alert, in every state.
        //
        // The app's own chime cannot be relied on: with the screen off SwiftUI
        // stops driving the view, so the tick that would fire it never runs,
        // and the rest lands in silence. The notification has no such
        // dependency — the system delivers it whether or not anything of ours
        // is awake — and on a muted watch it still taps the wrist, because
        // Silent Mode silences sound and not haptics. So the watch stops
        // trying to alert for itself and this is left to ring.
        //
        // The phone is the other way round: it is a screen you are looking at,
        // its own chime is the better alert, and the notification would be the
        // second of two.
        #if os(watchOS)
        [.banner, .sound, .list]
        #else
        isAppActive ? [.banner, .list] : [.banner, .sound, .list]
        #endif
    }

    /// Whether the app is in front, and therefore alerting for itself.
    private var isAppActive: Bool {
        #if os(watchOS)
        WKApplication.shared().applicationState == .active
        #elseif os(iOS)
        UIApplication.shared.applicationState == .active
        #else
        false
        #endif
    }
}

public enum RestAlerts {
    /// Call once at launch.
    @MainActor
    public static func installPresenter() {
        RestAlertPresenter.shared.install()
    }
}
#else
public enum RestAlerts {
    @MainActor
    public static func installPresenter() {}
}
#endif
