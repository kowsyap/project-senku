import SwiftUI
import SenkuCore

/// The output half of the calculator: what to eat, and why that number.
public struct ResultsView: View {
    private let plan: NutritionPlan
    private let unitSystem: UnitSystem

    public init(plan: NutritionPlan, unitSystem: UnitSystem = .metric) {
        self.plan = plan
        self.unitSystem = unitSystem
    }

    private var energy: EnergyProfile { plan.energy }
    private var macros: MacroTargets { plan.macros }

    public var body: some View {
        VStack(spacing: Senku.Metrics.stackSpacing) {
            targetCard
            if !plan.advisories.isEmpty {
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
        }
    }

    private var supportingTargets: some View {
        VStack(spacing: 8) {
            StatRow("Fiber", value: Display.grams(macros.fiberGrams))
            StatRow(
                "Water",
                value: Display.volume(macros.waterML, in: unitSystem),
                detail: "+\(Display.volume(macros.trainingDayExtraWaterML, in: unitSystem)) on training days"
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
            ForEach(plan.advisories) { advisory in
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
        let isEstimated = metrics.bodyFatPercentage == nil

        return Card("Body") {
            StatRow("BMI", value: String(format: "%.1f", metrics.bmi))
            StatRow(
                "Body fat",
                value: Display.percent(metrics.effectiveBodyFatPercentage),
                detail: isEstimated ? "Estimated from BMI" : "As measured"
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
