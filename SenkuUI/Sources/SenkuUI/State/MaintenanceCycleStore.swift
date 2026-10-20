import Foundation
import Observation

/// The day the current maintenance count began.
///
/// Set to today the first time it is read — the count starts from when the
/// feature first ran, not from history logged before it — and to the day of
/// each decision after that. See ``MaintenanceCheck``.
@Observable
public final class MaintenanceCycleStore {
    static let storageKey = "senku.maintenanceCycle.v1"

    private let defaults: UserDefaults
    private let fixedCalendar: Calendar?
    /// The logging calendar, read live so a change of day boundary applies at
    /// once; a test can fix one instead.
    private var calendar: Calendar { fixedCalendar ?? .logging }

    /// The first day of the count under way, as a start-of-day date.
    public private(set) var start: Date

    public init(
        defaults: UserDefaults = SenkuStorage.shared,
        calendar: Calendar? = nil,
        now: Date = .now
    ) {
        self.defaults = defaults
        self.fixedCalendar = calendar
        self.start = now
        reload(now: now)
    }

    /// Re-reads the stored day, or starts the count today if there is none.
    public func reload(now: Date = .now) {
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(Date.self, from: data) {
            start = DayBoundary.day(of: stored, in: calendar)
        } else {
            start = calendar.startOfDay(for: now)
            persist()
        }
    }

    /// After a decision: the count begins again today.
    public func restart(on date: Date = .now) {
        start = calendar.startOfDay(for: date)
        persist()
    }

    /// Moves the start forward past a fortnight that came out on track.
    /// Never back: a settled fortnight stays settled.
    public func advance(to day: Date) {
        let day = calendar.startOfDay(for: day)
        guard day > start else { return }
        start = day
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(start) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
