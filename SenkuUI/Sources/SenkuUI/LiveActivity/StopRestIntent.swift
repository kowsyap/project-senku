import Foundation
import SenkuCore

#if os(iOS) && !targetEnvironment(macCatalyst)
import AppIntents

/// Ends a rest from the Live Activity, without opening the app.
///
/// ## Why this is the answer to "I closed the app and it kept going"
///
/// iOS does not tell an app it was force quit. A suspended process swiped out
/// of the app switcher is killed with no callback, so there is no moment at
/// which Senku could tidy up — and the rest genuinely does keep running,
/// because everything it needs is already outside the app: the notification is
/// scheduled with the system, and the Live Activity animates from an absolute
/// deadline with no process of ours awake. That is the same reason the system
/// Clock's timer survives being swiped away.
///
/// What was missing was a way to *stop* it from out there. This is it: a button
/// on the Live Activity and in the Dynamic Island that ends the rest, cancels
/// the alert and clears the stored timer, in the app's own process, with
/// nothing brought to the foreground.
@available(iOS 17.0, *)
public struct StopRestIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "End rest"
    public static let description = IntentDescription("Ends the rest and dismisses it.")

    public static let openAppWhenRun = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        var timer = RestTimerStore.load() ?? RestTimer(preset: .ninetySeconds)
        timer.reset()

        RestTimerStore.clear()
        RestActivityController.shared.end(dismissing: .immediate)
        await RestChime.cancel()
        #if canImport(UserNotifications)
        RestNotifications.cancel()
        #endif
        RestDeepLink.notifyStarted()

        return .result()
    }
}

/// Adds thirty seconds from the Live Activity.
///
/// The other thing worth doing from outside the app: the set went long, and
/// reaching for the phone to unlock it is the one thing mid-set you do not want
/// to do.
@available(iOS 17.0, *)
public struct ExtendRestIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Add 30 seconds"
    public static let description = IntentDescription("Adds thirty seconds to the running rest.")

    public static let openAppWhenRun = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        guard var timer = RestTimerStore.load() else { return .result() }

        timer.extend(by: 30, at: .now)
        RestTimerStore.save(timer)
        RestActivityController.shared.sync(with: timer)
        await RestChime.sync(with: timer)
        #if canImport(UserNotifications)
        RestNotifications.sync(with: timer)
        #endif
        RestDeepLink.notifyStarted()

        return .result()
    }
}
#endif
