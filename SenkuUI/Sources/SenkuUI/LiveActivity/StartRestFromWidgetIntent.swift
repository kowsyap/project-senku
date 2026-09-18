import Foundation
import SenkuCore

// ActivityKit is iOS-only and absent on Mac Catalyst, and so is the guarantee
// this intent depends on. Everywhere else the widget falls back to its deep
// link, which opens the app and does the same work there.
#if os(iOS) && !targetEnvironment(macCatalyst)
import AppIntents

/// Starts a rest from the Home Screen widget, without opening the app.
///
/// The distinction from ``StartRestIntent`` is the conformance, and it is the
/// whole point: iOS runs a `LiveActivityIntent` in the *app's* process — in the
/// background, with no launch to the foreground — precisely so an intent can
/// start a Live Activity. A plain `AppIntent` run from a widget may execute in
/// the widget's own process instead, which on a build without the App Group
/// cannot hand the started rest to anyone.
///
/// So the tap lands where it should: the rest is running, the Dynamic Island
/// has it, the chime is scheduled, and the app stays where it was.
@available(iOS 17.0, *)
public struct StartRestFromWidgetIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Start a rest"
    public static let description = IntentDescription(
        "Starts the rest timer and shows it in the Dynamic Island."
    )

    /// The reason this exists. Nothing about a rest needs the app on screen.
    public static let openAppWhenRun = false

    @Parameter(title: "Seconds")
    public var seconds: Int

    public init() {
        self.seconds = Int(RestPreset.ninetySeconds.duration)
    }

    public init(seconds: TimeInterval) {
        self.seconds = Int(seconds)
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        // An unreadable duration falls back rather than refusing: the tap was
        // unambiguous, and a rest of about the right length beats none at all.
        var timer = (try? RestTimer(duration: TimeInterval(seconds)))
            ?? RestTimer(preset: .ninetySeconds)

        timer.start(at: .now)
        RestTimerStore.save(timer)

        RestActivityController.shared.sync(with: timer)
        // A rest started from the widget or the Dynamic Island still has to
        // chime on a silenced phone, so it holds the audio session too.
        RestChime.sync(with: timer)
        #if canImport(UserNotifications)
        RestNotifications.sync(with: timer)
        #endif

        // Only matters on a build with the App Group, where the widget can see
        // the rest it just started and should swap to the countdown.
        RestDeepLink.notifyStarted()

        return .result()
    }
}
#endif
