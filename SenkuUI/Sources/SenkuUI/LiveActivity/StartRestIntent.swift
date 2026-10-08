import Foundation
import SenkuCore

#if canImport(AppIntents)
import AppIntents

/// Starts a rest from outside the app — Control Center today, Siri and
/// Shortcuts for free.
///
/// The control runs in its own process, so this writes the started timer to the
/// shared store and opens the app, which picks it up on appear. It does not try
/// to reach into a running app: there may not be one.
@available(iOS 18.0, watchOS 11.0, macOS 15.0, *)
public struct StartRestIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start a rest"
    public static let description = IntentDescription(
        "Starts the rest timer at your last-used interval."
    )

    /// The app has to come forward: the countdown, the chime and the Live
    /// Activity all belong to it.
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        // Reuse whatever interval was last set, so the control matches what the
        // user has actually been resting for rather than guessing a default.
        // The same start as logging a set — the Live Activity, the chime that
        // still sounds on a silenced phone, the notification — written once.
        RestTimerStore.startAtLastInterval()
        return .result()
    }
}
#endif
