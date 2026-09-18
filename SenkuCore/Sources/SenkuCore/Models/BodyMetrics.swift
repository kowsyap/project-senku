import Foundation

/// A validated snapshot of the inputs every calculation in Senku depends on.
///
/// Values are stored in SI units (kilograms, centimetres) regardless of what the
/// user typed. Presentation converts on the way in and out, so no calculation
/// ever has to ask which unit system it is dealing with.
public struct BodyMetrics: Hashable, Codable, Sendable {
    /// The weights this app will accept, named so that anything else measuring
    /// a body weight — a weigh-in, an imported reading — validates against the
    /// same range rather than inventing its own.
    public static let allowedWeightKG: ClosedRange<Double> = 20...500

    public let sex: Sex
    public let age: Int
    public let heightCM: Double
    public let weightKG: Double

    /// Measured body fat, 3–70%. Unlocks the Katch-McArdle formula and
    /// lean-mass-based protein targets when present.
    public let bodyFatPercentage: Double?

    public init(
        sex: Sex,
        age: Int,
        heightCM: Double,
        weightKG: Double,
        bodyFatPercentage: Double? = nil
    ) throws {
        guard (13...120).contains(age) else {
            throw ValidationError.ageOutOfRange(age)
        }
        guard (50.0...272.0).contains(heightCM) else {
            throw ValidationError.heightOutOfRange(heightCM)
        }
        guard Self.allowedWeightKG.contains(weightKG) else {
            throw ValidationError.weightOutOfRange(weightKG)
        }
        if let bodyFatPercentage {
            guard (3.0...70.0).contains(bodyFatPercentage) else {
                throw ValidationError.bodyFatOutOfRange(bodyFatPercentage)
            }
        }

        self.sex = sex
        self.age = age
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.bodyFatPercentage = bodyFatPercentage
    }

    /// Convenience initializer for pounds, feet and inches.
    public init(
        sex: Sex,
        age: Int,
        feet: Int,
        inches: Double,
        pounds: Double,
        bodyFatPercentage: Double? = nil
    ) throws {
        try self.init(
            sex: sex,
            age: age,
            heightCM: (Double(feet) * 12 + inches) * 2.54,
            weightKG: pounds * 0.453_592_37,
            bodyFatPercentage: bodyFatPercentage
        )
    }

    public var heightMeters: Double { heightCM / 100 }

    public var bmi: Double {
        weightKG / (heightMeters * heightMeters)
    }

    /// Deurenberg estimate, used only when the user has not measured body fat.
    /// Accurate to roughly ±5 points, so it is offered as a hint, never as fact.
    public var estimatedBodyFatPercentage: Double {
        (1.20 * bmi) + (0.23 * Double(age)) - (10.8 * sex.deurenbergFactor) - 5.4
    }

    /// Measured body fat when available, otherwise the Deurenberg estimate.
    public var effectiveBodyFatPercentage: Double {
        bodyFatPercentage ?? max(3, min(70, estimatedBodyFatPercentage))
    }

    public var leanBodyMassKG: Double {
        weightKG * (1 - effectiveBodyFatPercentage / 100)
    }

    public var fatMassKG: Double {
        weightKG - leanBodyMassKG
    }

    /// Healthy weight span for this height, from the WHO BMI range of 18.5–24.9.
    public var healthyWeightRangeKG: ClosedRange<Double> {
        let square = heightMeters * heightMeters
        return (18.5 * square)...(24.9 * square)
    }
}

public enum ValidationError: Error, Equatable, Sendable {
    case ageOutOfRange(Int)
    case heightOutOfRange(Double)
    case weightOutOfRange(Double)
    case bodyFatOutOfRange(Double)
    case restDurationOutOfRange(TimeInterval)
    case liftedWeightOutOfRange(Double)
    case repsOutOfRange(Int)
    case waterOutOfRange(Double)
    case macroOutOfRange(Double)
}

extension ValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .ageOutOfRange:
            "Age must be between 13 and 120. Senku's formulas are not validated outside that range."
        case .heightOutOfRange:
            "Height must be between 50 cm and 272 cm."
        case .weightOutOfRange:
            "Weight must be between 20 kg and 500 kg."
        case .bodyFatOutOfRange:
            "Body fat must be between 3% and 70%."
        case .waterOutOfRange:
            "That is not a drink — give an amount between 1 ml and 5 litres."
        case .macroOutOfRange:
            "Grams must be between 0 and 1,000. Anything outside that is a typing slip, not a meal."
        case .liftedWeightOutOfRange:
            "A lift must be between 0 kg and 1,000 kg — zero meaning bodyweight."
        case .repsOutOfRange:
            "Reps must be between 1 and 100."
        case .restDurationOutOfRange:
            "A rest timer must be between 5 seconds and 60 minutes."
        }
    }
}
