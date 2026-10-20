import Foundation
import SenkuCore

/// What a target was, day by day: each change, and the day it took effect.
///
/// ## Why
///
/// A streak day is a day you hit the target you had. Judged against today's
/// instead, every change of plan rewrote the past: accept a measured
/// maintenance, and a month of days on target became a month of misses. So
/// each change is kept, and a past day is judged by the one in force on it.
///
/// Kept from the day this shipped. Before the first change there is nothing
/// to go on, so earlier days take the earliest target known — which is what
/// every day took before.
struct TargetHistory<Value: Codable & Equatable> {
    let key: String
    let defaults: UserDefaults
    let calendar: Calendar

    private struct Change: Codable {
        let day: Date
        let value: Value
    }

    /// Oldest first, each on the day it means under the current day boundary.
    private var changes: [Change] {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode([Change].self, from: data)
        else { return [] }
        return stored
            .map { Change(day: DayBoundary.day(of: $0.day, in: calendar), value: $0.value) }
            .sorted { $0.day < $1.day }
    }

    /// The target in force on a day, or nil when none has been kept yet.
    func value(on date: Date) -> Value? {
        let day = calendar.startOfDay(for: date)
        let changes = changes
        return (changes.last { $0.day <= day } ?? changes.first)?.value
    }

    /// Notes the target in force from today. Nothing when it has not changed;
    /// a second change on the same day replaces the first, since a day is
    /// judged by where it ended up.
    func record(_ value: Value, on date: Date = .now) {
        var changes = changes
        guard changes.last?.value != value else { return }

        let day = calendar.startOfDay(for: date)
        if changes.last?.day == day {
            changes.removeLast()
        }
        // Back to what the day before had: the change cancelled itself.
        if changes.last?.value != value {
            changes.append(Change(day: day, value: value))
        }

        guard let data = try? JSONEncoder().encode(changes) else { return }
        defaults.set(data, forKey: key)
    }
}

/// The two food targets a streak looks at.
struct FoodTargets: Codable, Equatable {
    var calories: Double
    var proteinGrams: Double
}

/// The parts of the water goal that are chosen rather than lived: the base
/// from the profile, what a training day adds, creatine, and a goal set by
/// hand. Whether a day was a training day is in the workout log already.
struct WaterTargets: Codable, Equatable {
    var baseML: Double
    var trainingExtraML: Double
    var creatineML: Double
    var overrideML: Double?
}
