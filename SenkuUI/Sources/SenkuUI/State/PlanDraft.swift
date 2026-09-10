import Foundation
import Observation
import SenkuCore

/// The editable state behind the calculator.
///
/// Values are held in SI units even while the user types imperial, so switching
/// unit systems mid-edit never loses precision or round-trips through a string.
/// `plan` recomputes on every change — the core is pure and synchronous, so this
/// is cheap enough to do per keystroke.
@Observable
public final class PlanDraft {
    public var unitSystem: UnitSystem
    public var sex: Sex
    public var age: Int
    public var heightCM: Double
    public var weightKG: Double

    /// Whether the user has a measured body fat number to offer. When false the
    /// core falls back to a BMI estimate and says so in an advisory.
    public var usesMeasuredBodyFat: Bool
    public var bodyFatPercentage: Double

    public var activityLevel: ActivityLevel
    public var goal: Goal
    public var formula: BMRFormula

    public init(
        unitSystem: UnitSystem = .metric,
        sex: Sex = .male,
        age: Int = 30,
        heightCM: Double = 175,
        weightKG: Double = 75,
        usesMeasuredBodyFat: Bool = false,
        bodyFatPercentage: Double = 20,
        activityLevel: ActivityLevel = .moderate,
        goal: Goal = .maintain,
        formula: BMRFormula = .automatic
    ) {
        self.unitSystem = unitSystem
        self.sex = sex
        self.age = age
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.usesMeasuredBodyFat = usesMeasuredBodyFat
        self.bodyFatPercentage = bodyFatPercentage
        self.activityLevel = activityLevel
        self.goal = goal
        self.formula = formula
    }

    // MARK: - Imperial bridges

    /// Weight in pounds. Writing through this keeps kilograms authoritative.
    public var weightPounds: Double {
        get { Convert.pounds(fromKilograms: weightKG) }
        set { weightKG = Convert.kilograms(fromPounds: newValue) }
    }

    public var heightFeet: Int {
        get { Convert.feetAndInches(fromCentimetres: heightCM).feet }
        set { heightCM = Convert.centimetres(feet: newValue, inches: heightInches) }
    }

    public var heightInches: Double {
        get { Convert.feetAndInches(fromCentimetres: heightCM).inches }
        set { heightCM = Convert.centimetres(feet: heightFeet, inches: newValue) }
    }

    // MARK: - Derived

    public var metrics: BodyMetrics? {
        try? BodyMetrics(
            sex: sex,
            age: age,
            heightCM: heightCM,
            weightKG: weightKG,
            bodyFatPercentage: usesMeasuredBodyFat ? bodyFatPercentage : nil
        )
    }

    /// The current plan, or nil while the inputs are not yet valid.
    public var plan: NutritionPlan? {
        guard let metrics else { return nil }
        return NutritionPlan.make(
            for: metrics,
            activityLevel: activityLevel,
            goal: goal,
            formula: formula
        )
    }

    /// Why the inputs are not usable, phrased for display under the form.
    public var validationMessage: String? {
        do {
            _ = try BodyMetrics(
                sex: sex,
                age: age,
                heightCM: heightCM,
                weightKG: weightKG,
                bodyFatPercentage: usesMeasuredBodyFat ? bodyFatPercentage : nil
            )
            return nil
        } catch let error as ValidationError {
            return error.errorDescription
        } catch {
            return "Those numbers do not look right."
        }
    }
}
