import Foundation
import SenkuCore

// ActivityKit exists on macOS as a module but every type in it is unavailable
// there, so `canImport` is not a strong enough guard. Mac Catalyst reports
// `os(iOS)` and has no Live Activities either.
#if os(iOS)
import ActivityKit

/// The Live Activity's payload.
///
/// The content state is the whole ``RestTimer``, not a snapshot of derived
/// numbers. That is the point of the engine storing a deadline: the value is
/// small, `Codable`, and answers every question the lock screen needs from a
/// `now` the system supplies. So the app never has to push a tick — it pushes
/// once when something actually changes, and the widget counts down on its own
/// with no process of ours awake.
public struct RestActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var timer: RestTimer

        public init(timer: RestTimer) {
            self.timer = timer
        }
    }

    /// Fixed for the life of the activity. Nothing here changes per update.
    public var startedAt: Date

    public init(startedAt: Date = .now) {
        self.startedAt = startedAt
    }
}
#endif
