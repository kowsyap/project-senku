import Foundation
import SenkuCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// `senku://rest/start?seconds=90` — how the Home Screen widget starts a rest.
///
/// A deep link rather than an App Intent on purpose. An intent run from a
/// widget may execute in the *widget's* process, which on a build without the
/// App Group cannot hand anything back to the app. Opening a URL always wakes
/// the app and runs the work here, in the app's own process, so the widget
/// works whether or not the App Group is available.
public enum RestDeepLink {
    public static let scheme = "senku"

    /// Posted once a link has started a rest, so a timer screen already on
    /// display picks it up instead of waiting for its next `onAppear`.
    public static let didStart = Notification.Name("senku.rest.didStartFromLink")

    /// Announces a rest that was started from outside a timer screen, so one
    /// already on display picks it up instead of waiting for its next
    /// `onAppear`, and the widget redraws against the new state.
    public static func notifyStarted() {
        NotificationCenter.default.post(name: didStart, object: nil)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public static func url(seconds: TimeInterval) -> URL {
        URL(string: "\(scheme)://rest/start?seconds=\(Int(seconds))")!
    }

    /// - Returns: the started timer, or `nil` if the URL was not ours.
    @discardableResult
    public static func handle(_ url: URL, at now: Date = .now) -> RestTimer? {
        guard url.scheme == scheme, url.host == "rest" else { return nil }
        guard url.path == "/start" else { return nil }

        let seconds = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "seconds" }
            .flatMap { $0.value }
            .flatMap(TimeInterval.init)

        // An unreadable or out-of-range duration falls back to the last one
        // used rather than refusing: the tap was unambiguous either way.
        let fallback = RestTimerStore.load()?.duration ?? RestPreset.ninetySeconds.duration
        var timer = (seconds.flatMap { try? RestTimer(duration: $0) })
            ?? ((try? RestTimer(duration: fallback)) ?? RestTimer(preset: .ninetySeconds))

        timer.start(at: now)
        RestTimerStore.save(timer)
        notifyStarted()
        return timer
    }
}
