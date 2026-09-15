import Foundation
import SenkuCore

// ActivityKit exists on macOS as a module but every type in it is unavailable
// there, so `canImport` is not a strong enough guard. Mac Catalyst reports
// `os(iOS)` and has no Live Activities either.
#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit

/// Keeps a Live Activity in step with the on-screen timer.
///
/// Updates are pushed on *state changes only* — start, pause, resume, retarget,
/// finish — never on the tick. The lock screen animates its own countdown from
/// the deadline inside the content state, so a per-second push would be both
/// wasteful and, past the system's update budget, throttled into being wrong.
///
/// ## Why this is not `@MainActor`
///
/// `ActivityKit.Activity` is not `Sendable`, and `update` and `end` are
/// `nonisolated async`. Isolating the handle to the main actor would make every
/// call into ActivityKit a cross-isolation send of a non-`Sendable` value,
/// which Swift 6 rejects outright. So the handle stays unisolated and its own
/// mutation is serialised by a lock instead — the narrower guarantee, and the
/// one that actually matches what needs protecting.
public final class RestActivityController: @unchecked Sendable {
    public static let shared = RestActivityController()

    private let lock = NSLock()
    private var stored: Activity<RestActivityAttributes>?

    private var activity: Activity<RestActivityAttributes>? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }

    private init() {}

    /// Whether the user has Live Activities switched on for Senku. There is no
    /// permission prompt to trigger; it is a Settings toggle, so the only
    /// correct response to `false` is to carry on silently.
    public var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Mirrors `timer` onto the lock screen, starting or ending the activity as
    /// its phase requires. Safe to call on every change; it is a no-op when
    /// there is nothing to do.
    public func sync(with timer: RestTimer, at now: Date = .now) {
        guard isAvailable else { return }

        // Nothing to show for a timer that has not started or has been reset.
        //
        // Dismissed immediately rather than by the default policy, which leaves
        // the activity on the lock screen for up to four hours. That is right
        // for a rest that ran its course and wrong for one you just deleted:
        // reset means gone now.
        guard !timer.isIdle else {
            end(dismissing: .immediate)
            return
        }

        let content = ActivityContent(
            state: RestActivityAttributes.ContentState(timer: timer),
            staleDate: timer.endsAt?.addingTimeInterval(60)
        )

        if let activity {
            Task { await activity.update(content) }
        } else {
            activity = try? Activity.request(
                attributes: RestActivityAttributes(startedAt: now),
                content: content,
                pushType: nil
            )
        }
    }

    /// Dismisses the activity.
    public func end(dismissing policy: ActivityUIDismissalPolicy = .default) {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: policy) }
    }
}
#endif
