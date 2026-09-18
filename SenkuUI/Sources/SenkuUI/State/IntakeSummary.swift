import Foundation
import SenkuCore

/// The little of the food log a watch needs.
///
/// Four numbers and the day they belong to. The watch draws two rings and
/// offers two buttons; it has no use for the individual meals, and sending
/// them would be a payload that grows all day for a screen that only adds
/// them up again.
///
/// The `date` is what makes it safe: a summary sent yesterday is recognisably
/// yesterday's, so a watch that has been in a drawer shows empty rings for today
/// rather than a full pair from a day that is over. The same rule as
/// ``WaterSummary``, for the same reason.
public struct IntakeSummary: Codable, Hashable, Sendable {
    public var date: Date
    public var proteinG: Double
    public var proteinTargetG: Double
    public var calories: Double
    public var calorieTarget: Double
    /// Whether the phone has a profile at all. Without one there are no targets
    /// and the watch says so, rather than drawing two rings against invented
    /// numbers.
    public var hasTargets: Bool

    public init(
        date: Date = .now,
        proteinG: Double = 0,
        proteinTargetG: Double = 0,
        calories: Double = 0,
        calorieTarget: Double = 0,
        hasTargets: Bool = false
    ) {
        self.date = date
        self.proteinG = proteinG
        self.proteinTargetG = proteinTargetG
        self.calories = calories
        self.calorieTarget = calorieTarget
        self.hasTargets = hasTargets
    }

    @MainActor
    public init(store: IntakeStore, profile: ProfileStore.Profile?) {
        guard let day = store.day(profile: profile) else {
            self.init(date: .now)
            return
        }

        self.init(
            date: .now,
            proteinG: day.proteinG,
            proteinTargetG: day.targets.proteinGrams,
            calories: day.calories,
            calorieTarget: day.targets.calories,
            hasTargets: true
        )
    }

    public func isCurrent(_ calendar: Calendar = .current) -> Bool {
        calendar.isDateInToday(date)
    }

    public var proteinFraction: Double {
        guard proteinTargetG > 0 else { return 0 }
        return min(1, proteinG / proteinTargetG)
    }

    public var calorieFraction: Double {
        guard calorieTarget > 0 else { return 0 }
        return min(1, calories / calorieTarget)
    }

    public var proteinRemainingG: Double { max(0, proteinTargetG - proteinG) }
    public var caloriesRemaining: Double { max(0, calorieTarget - calories) }

    public var isProteinMet: Bool { proteinTargetG > 0 && proteinG >= proteinTargetG }

    /// The same band the phone judges a day by — see `IntakeDay.isCaloriesMet`.
    public var isCaloriesMet: Bool {
        guard calorieTarget > 0, calories > 0 else { return false }
        return abs(calories - calorieTarget) <= calorieTarget * IntakeDay.calorieTolerance
    }

    public var isOverCalories: Bool {
        calorieTarget > 0 && calories > calorieTarget * (1 + IntakeDay.calorieTolerance)
    }
}
