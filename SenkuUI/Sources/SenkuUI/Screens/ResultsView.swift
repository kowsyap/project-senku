import SwiftUI
import SenkuCore

/// The output half of the calculator: what to eat, and why that number.
public struct ResultsView: View {
    private let plan: NutritionPlan
    private let unitSystem: UnitSystem

    /// False where the caller places the advisories itself — the Me page puts
    /// them last, after the maintenance figure they sit beside.
    private let showsAdvisories: Bool

    /// The plan before the Food tab's adjustments, when there are any — so the
    /// target card can say the numbers are not the calculator's own.
    private let calculatorPlan: NutritionPlan?

    public init(
        plan: NutritionPlan,
        unitSystem: UnitSystem = .metric,
        showsAdvisories: Bool = true,
        calculatorPlan: NutritionPlan? = nil
    ) {
        self.showsAdvisories = showsAdvisories
        self.plan = plan
        self.unitSystem = unitSystem
        self.calculatorPlan = calculatorPlan
    }

    private var energy: EnergyProfile { plan.energy }
    private var macros: MacroTargets { plan.macros }

    public var body: some View {
        VStack(spacing: Senku.Metrics.stackSpacing) {
            targetCard
            if showsAdvisories, !plan.bannerAdvisories.isEmpty {
                advisoriesCard
            }
            energyCard
            bodyCard
        }
    }

    // MARK: - Target

    private var targetCard: some View {
        Card(plan.energy.goal.title, footnote: plan.energy.goal.detail) {
            ViewThatFits(in: .horizontal) {
                // Side by side, but only where there is genuinely room for it.
                // The minimum width is what makes the choice deterministic:
                // below it this branch cannot fit and the stacked one is used.
                HStack(alignment: .center, spacing: 24) {
                    MacroRing(macros: macros)
                        .frame(width: 150, height: 150)
                    VStack(spacing: 12) {
                        MacroLegend(macros: macros)
                        Divider()
                        supportingTargets
                    }
                }
                .frame(minWidth: 460)

                VStack(spacing: 16) {
                    MacroRing(macros: macros)
                        .frame(width: 168, height: 168)
                        .padding(.top, 4)
                    MacroLegend(macros: macros)
                    Divider()
                    supportingTargets
                }
            }

            Divider()
            projection

            if let calculatorPlan {
                Divider()
                adjustment(from: calculatorPlan)
            }
        }
    }

    /// What the Food tab changed, against what the calculator worked out.
    private func adjustment(from calculator: NutritionPlan) -> some View {
        let calories = macros.calories - calculator.macros.calories
        let protein = macros.proteinGrams - calculator.macros.proteinGrams
        var parts: [String] = []
        if abs(calories) >= 1 { parts.append("\(Display.signedCalories(calories)) kcal") }
        if abs(protein) >= 1 { parts.append("\(protein > 0 ? "+" : "")\(Int(protein.rounded())) g protein") }

        return StatRow(
            "Your adjustment",
            value: parts.isEmpty ? "None" : parts.joined(separator: ", "),
            detail: "Calculator: \(Display.calories(calculator.macros.calories)) kcal, \(Display.grams(calculator.macros.proteinGrams))"
        )
    }

    private var supportingTargets: some View {
        VStack(spacing: 8) {
            StatRow("Fiber", value: Display.grams(macros.fiberGrams))
            StatRow(
                "Water",
                value: Display.millilitres(macros.waterML),
                detail: "+\(Display.millilitres(macros.trainingDayExtraWaterML)) on training days"
            )
        }
    }

    @ViewBuilder
    private var projection: some View {
        let delta = energy.dailyDelta
        let tint: Color? = if delta < 0 {
            Senku.Palette.deficit
        } else if delta > 0 {
            Senku.Palette.surplus
        } else {
            nil
        }

        VStack(spacing: 8) {
            StatRow(
                "Maintenance",
                value: "\(Display.calories(energy.maintenanceCalories)) kcal",
                detail: "What you burn at your activity level"
            )
            if abs(delta) >= 1 {
                StatRow(
                    delta < 0 ? "Daily deficit" : "Daily surplus",
                    value: "\(Display.signedCalories(delta)) kcal",
                    tint: tint
                )
                StatRow(
                    "Expected change",
                    value: "\(Display.massDelta(plan.projectedWeeklyChangeKG, in: unitSystem))/week",
                    tint: tint
                )
            }
        }
    }

    // MARK: - Supporting cards

    private var advisoriesCard: some View {
        VStack(spacing: 8) {
            ForEach(plan.bannerAdvisories) { advisory in
                AdvisoryBanner(advisory)
            }
        }
    }

    private var energyCard: some View {
        Card(
            "Energy",
            footnote: "Calculated with \(energy.formulaUsed.title)."
        ) {
            StatRow(
                "Basal rate",
                value: "\(Display.calories(energy.basalMetabolicRate)) kcal",
                detail: "What you would burn doing nothing at all",
                isProminent: true
            )
            Divider()
            EnergyLadder(energy: energy)
        }
    }

    private var bodyCard: some View {
        let metrics = plan.metrics

        return Card("Body") {
            StatRow(
                "BMI",
                value: String(format: "%.1f", metrics.bmi),
                info: plan.note(Advisory.bmiLow)
            )
            StatRow(
                "Body fat",
                value: Display.percent(metrics.effectiveBodyFatPercentage),
                info: plan.note(Advisory.bodyFatEstimated)
            )
            StatRow("Lean mass", value: Display.mass(metrics.leanBodyMassKG, in: unitSystem))
            StatRow("Fat mass", value: Display.mass(metrics.fatMassKG, in: unitSystem))
            StatRow(
                "Healthy range",
                value: Display.range(metrics.healthyWeightRangeKG, in: unitSystem),
                detail: "BMI 18.5–24.9 for your height"
            )
        }
    }
}

extension Advisory {
    static let bmiLow = "bmi.low"
    static let bodyFatEstimated = "bodyfat.estimated"

    /// Notes about a single figure, shown in an info button beside it rather
    /// than as a banner: "your BMI is below the healthy range" means most next
    /// to the BMI.
    static let besideTheirFigure: Set<String> = [bmiLow, bodyFatEstimated]
}

extension NutritionPlan {
    /// The advisories that still get a banner of their own.
    var bannerAdvisories: [Advisory] {
        advisories.filter { !Advisory.besideTheirFigure.contains($0.id) }
    }

    /// One figure's note, with its severity's colour, if the plan has it.
    func note(_ id: String) -> (text: String, tint: Color)? {
        advisories.first { $0.id == id }.map { ($0.message, $0.severity.tint) }
    }
}
