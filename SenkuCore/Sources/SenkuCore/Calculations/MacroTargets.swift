import Foundation

/// Atwater factors: calories yielded per gram of each macronutrient.
public enum CaloriesPerGram {
    public static let protein: Double = 4
    public static let carbohydrate: Double = 4
    public static let fat: Double = 9
}

public struct MacroTargets: Hashable, Sendable {
    public let calories: Double
    public let proteinGrams: Double
    public let fatGrams: Double
    public let carbGrams: Double
    public let fiberGrams: Double

    /// Baseline daily fluid target in millilitres, before training is counted.
    public let waterML: Double

    /// Extra fluid to drink on days you train.
    public let trainingDayExtraWaterML: Double

    public var proteinCalories: Double { proteinGrams * CaloriesPerGram.protein }
    public var carbCalories: Double { carbGrams * CaloriesPerGram.carbohydrate }
    public var fatCalories: Double { fatGrams * CaloriesPerGram.fat }

    public var proteinPercentage: Double { share(of: proteinCalories) }
    public var carbPercentage: Double { share(of: carbCalories) }
    public var fatPercentage: Double { share(of: fatCalories) }

    private func share(of value: Double) -> Double {
        guard calories > 0 else { return 0 }
        return value / calories * 100
    }
}

public enum MacroCalculator {
    /// Protein per kg of the chosen basis. Lean mass tolerates a higher number
    /// than total bodyweight, which is why the two sets differ.
    struct ProteinRates {
        let perKGLeanMass: Double
        let perKGBodyweight: Double
    }

    static func proteinRates(for goal: Goal) -> ProteinRates {
        if goal.isCut {
            // Protein does the most work on a cut: it protects lean mass and
            // is the most satiating macro when calories are low.
            return ProteinRates(perKGLeanMass: 2.4, perKGBodyweight: 2.2)
        } else if goal.isBulk {
            return ProteinRates(perKGLeanMass: 2.2, perKGBodyweight: 1.8)
        } else {
            return ProteinRates(perKGLeanMass: 2.0, perKGBodyweight: 1.8)
        }
    }

    /// Share of calories from fat before any flooring.
    static func fatFraction(for goal: Goal) -> Double {
        goal.isCut ? 0.22 : 0.25
    }

    /// Fat cannot be cut to nothing — hormone production and fat-soluble
    /// vitamin absorption both depend on a minimum intake.
    static let essentialFatPerKG: Double = 0.5

    /// Protein above this share of intake squeezes out the other two macros
    /// without further benefit.
    static let maxProteinCalorieShare: Double = 0.40

    public static func targets(
        for metrics: BodyMetrics,
        energy: EnergyProfile
    ) -> MacroTargets {
        let calories = energy.targetCalories
        let goal = energy.goal

        // Protein, from lean mass when it was measured rather than estimated.
        let rates = proteinRates(for: goal)
        let rawProtein: Double = if metrics.bodyFatPercentage != nil {
            metrics.leanBodyMassKG * rates.perKGLeanMass
        } else {
            metrics.weightKG * rates.perKGBodyweight
        }
        let proteinCeiling = calories * maxProteinCalorieShare / CaloriesPerGram.protein
        var protein = min(rawProtein, proteinCeiling)

        // Fat, as a share of intake but never below the essential minimum.
        let essentialFat = metrics.weightKG * essentialFatPerKG
        var fat = max(
            calories * fatFraction(for: goal) / CaloriesPerGram.fat,
            essentialFat
        )

        // At very low intakes protein and fat can together exceed the budget.
        // Give up fat first, down to the essential floor, then protein.
        var remaining = calories - (protein * CaloriesPerGram.protein) - (fat * CaloriesPerGram.fat)
        if remaining < 0 {
            let reducibleFat = max(0, fat - essentialFat)
            let fatToDrop = min(reducibleFat, -remaining / CaloriesPerGram.fat)
            fat -= fatToDrop
            remaining += fatToDrop * CaloriesPerGram.fat
        }
        if remaining < 0 {
            protein = max(0, protein + remaining / CaloriesPerGram.protein)
            remaining = 0
        }

        let carbs = max(0, remaining / CaloriesPerGram.carbohydrate)

        // 14 g per 1000 kcal is the US Dietary Guidelines figure, bounded so
        // very low or very high intakes stay in a range people can actually eat.
        let fiber = min(45, max(20, calories / 1000 * 14))

        return MacroTargets(
            calories: calories.roundedTo(nearest: 10),
            proteinGrams: protein.rounded(),
            fatGrams: fat.rounded(),
            carbGrams: carbs.rounded(),
            fiberGrams: fiber.rounded(),
            waterML: (metrics.weightKG * 35).roundedTo(nearest: 50),
            trainingDayExtraWaterML: 500
        )
    }
}

extension Double {
    func roundedTo(nearest: Double) -> Double {
        guard nearest > 0 else { return self.rounded() }
        return (self / nearest).rounded() * nearest
    }
}
