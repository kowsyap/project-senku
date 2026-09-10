import Foundation
import SenkuCore

enum Format {
    static func kcal(_ value: Double) -> String {
        "\(Int(value.rounded())) kcal"
    }

    static func grams(_ value: Double) -> String {
        "\(Int(value.rounded())) g"
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    static func signed(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded >= 0 ? "+\(rounded)" : "\(rounded)"
    }

    static func row(_ label: String, _ value: String, width: Int = 26) -> String {
        let padding = max(1, width - label.count)
        return "  \(label)\(String(repeating: " ", count: padding))\(value)"
    }

    static func heading(_ text: String) -> String {
        "\n\(text)\n  \(String(repeating: "─", count: max(0, text.count + 8)))"
    }
}

func render(_ plan: NutritionPlan) -> String {
    let m = plan.metrics
    let e = plan.energy
    let macros = plan.macros
    var out: [String] = []

    out.append(Format.heading("YOU"))
    out.append(Format.row("Sex / age", "\(m.sex.rawValue), \(m.age)"))
    out.append(Format.row("Height / weight", String(format: "%.0f cm, %.1f kg", m.heightCM, m.weightKG)))
    out.append(Format.row("BMI", String(format: "%.1f", m.bmi)))
    let bodyFatNote = m.bodyFatPercentage == nil ? " (estimated)" : " (measured)"
    out.append(Format.row("Body fat", String(format: "%.1f%%", m.effectiveBodyFatPercentage) + bodyFatNote))
    out.append(Format.row("Lean mass", String(format: "%.1f kg", m.leanBodyMassKG)))
    out.append(Format.row(
        "Healthy weight range",
        String(format: "%.1f–%.1f kg", m.healthyWeightRangeKG.lowerBound, m.healthyWeightRangeKG.upperBound)
    ))

    out.append(Format.heading("ENERGY  (\(e.formulaUsed.title))"))
    out.append(Format.row("Basal (BMR)", Format.kcal(e.basalMetabolicRate)))
    out.append(Format.row("At rest (RMR)", Format.kcal(e.restingMetabolicRate)))
    for level in ActivityLevel.allCases {
        let marker = level == e.activityLevel ? " ←" : ""
        out.append(Format.row("  \(level.title)", Format.kcal(e.expenditure(at: level)) + marker))
    }

    out.append(Format.heading("TARGET  (\(e.goal.title))"))
    out.append(Format.row("Maintenance", Format.kcal(e.maintenanceCalories)))
    out.append(Format.row("Daily target", Format.kcal(e.targetCalories)))
    out.append(Format.row("Delta", "\(Format.signed(e.dailyDelta)) kcal/day"))
    out.append(Format.row("Projected change", String(format: "%+.2f kg/week", plan.projectedWeeklyChangeKG)))

    out.append(Format.heading("MACROS"))
    out.append(Format.row("Protein", "\(Format.grams(macros.proteinGrams))  (\(Format.percent(macros.proteinPercentage)))"))
    out.append(Format.row("Carbs", "\(Format.grams(macros.carbGrams))  (\(Format.percent(macros.carbPercentage)))"))
    out.append(Format.row("Fat", "\(Format.grams(macros.fatGrams))  (\(Format.percent(macros.fatPercentage)))"))
    out.append(Format.row("Fiber", Format.grams(macros.fiberGrams)))
    out.append(Format.row("Water", "\(Int(macros.waterML)) ml  (+\(Int(macros.trainingDayExtraWaterML)) training days)"))

    if !plan.advisories.isEmpty {
        out.append(Format.heading("NOTES"))
        for advisory in plan.advisories {
            let tag = switch advisory.severity {
            case .warning: "!"
            case .caution: "*"
            case .info: "-"
            }
            out.append("  \(tag) \(advisory.message.replacingOccurrences(of: "\n", with: " "))")
        }
    }

    return out.joined(separator: "\n")
}
