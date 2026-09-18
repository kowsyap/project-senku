import Foundation
import SenkuCore

/// The little of the water log a watch needs.
///
/// Two numbers and the day they belong to. The watch shows a bottle filling and
/// what is left, and neither needs the individual drinks — sending them would
/// be a growing payload every hour for a screen that adds them up again.
///
/// The `date` is what makes it safe: a summary sent yesterday is recognisably
/// yesterday's, so a watch that has been in a drawer shows an empty bottle for
/// today rather than a full one from a day that is over.
public struct WaterSummary: Codable, Hashable, Sendable {
    public var date: Date
    public var totalML: Double
    public var goalML: Double
    /// What the three buttons pour, in the sizes set on the phone.
    public var containers: [Double]

    public init(
        date: Date = .now,
        totalML: Double = 0,
        goalML: Double = 2000,
        containers: [Double] = [250, 500, 750]
    ) {
        self.date = date
        self.totalML = totalML
        self.goalML = goalML
        self.containers = containers
    }

    @MainActor
    public init(store: WaterStore, profile: ProfileStore.Profile?, workouts: WorkoutStore?) {
        let day = store.day(profile: profile, workouts: workouts)
        self.date = .now
        self.totalML = day.totalML
        self.goalML = day.goal.totalML
        self.containers = store.settings.containers.map(\.millilitres)
    }

    /// Whether this is about today. A summary from another day says nothing
    /// about this one.
    public func isCurrent(_ calendar: Calendar = .current) -> Bool {
        calendar.isDateInToday(date)
    }

    public var fraction: Double {
        guard goalML > 0 else { return 0 }
        return min(1, totalML / goalML)
    }

    public var remainingML: Double { max(0, goalML - totalML) }
}
