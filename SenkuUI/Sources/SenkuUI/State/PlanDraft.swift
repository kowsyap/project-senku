import Foundation
import Observation
import SenkuCore

/// The editable state behind the calculator.
///
/// Values are held in SI units even while the user types imperial, so switching
/// unit systems mid-edit never loses precision or round-trips through a string.
/// `plan` recomputes on every change — the core is pure and synchronous, so this
/// is cheap enough to do per keystroke.
/// `Identifiable` so a draft can drive `sheet(item:)` — opening the profile
/// editor and seeding it with the current profile become one action. A class
/// gets its identity from `ObjectIdentifier` for free.
@Observable
public final class PlanDraft: Identifiable {
    public var unitSystem: UnitSystem
    public var sex: Sex

    /// Optional because a fresh calculator starts **empty**. A pre-filled age
    /// of 30 is not a neutral default — it is a number the user never entered
    /// but which quietly produces a plausible-looking plan, which is exactly
    /// the kind of unearned answer this app is supposed to refuse.
    public var age: Int?
    public var heightCM: Double?
    public var weightKG: Double?

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
        age: Int? = nil,
        heightCM: Double? = nil,
        weightKG: Double? = nil,
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
    /// `nil` in and `nil` out, so an empty field stays empty across a unit
    /// switch instead of materialising a zero.
    public var weightPounds: Double? {
        get { weightKG.map(Convert.pounds(fromKilograms:)) }
        set { weightKG = newValue.map(Convert.kilograms(fromPounds:)) }
    }

    public var heightFeet: Int? {
        get { heightCM.map { Convert.feetAndInches(fromCentimetres: $0).feet } }
        set {
            guard let newValue else { heightCM = nil; return }
            heightCM = Convert.centimetres(feet: newValue, inches: heightInches ?? 0)
        }
    }

    public var heightInches: Double? {
        get { heightCM.map { Convert.feetAndInches(fromCentimetres: $0).inches } }
        set {
            guard let newValue else { heightCM = nil; return }
            heightCM = Convert.centimetres(feet: heightFeet ?? 0, inches: newValue)
        }
    }

    // MARK: - Completeness

    /// The inputs with no answer yet, named as the form labels them.
    public var missingFields: [String] {
        var missing: [String] = []
        if age == nil { missing.append("Age") }
        if heightCM == nil { missing.append("Height") }
        if weightKG == nil { missing.append("Weight") }
        return missing
    }

    /// Every required field has a value. Says nothing about whether those
    /// values are *sane* — `validationMessage` answers that.
    public var isComplete: Bool { missingFields.isEmpty }

    // MARK: - Derived

    public var metrics: BodyMetrics? {
        guard let age, let heightCM, let weightKG else { return nil }
        return try? BodyMetrics(
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
    /// Missing answers are reported before out-of-range ones, because "fill in
    /// your weight" is more use than a range you have not reached yet.
    public var validationMessage: String? {
        guard let age, let heightCM, let weightKG else {
            let missing = missingFields
            return missing.count == 1
                ? "\(missing[0]) is needed before Senku can work anything out."
                : "\(missing.dropLast().joined(separator: ", ")) and \(missing[missing.count - 1]) are needed before Senku can work anything out."
        }
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
