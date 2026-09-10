#if os(watchOS)
import SwiftUI
import SenkuCore

/// Today's targets, sized for a glance between sets.
///
/// This is deliberately not a port of the phone screen. A watch is read for
/// about three seconds with one hand occupied, so it shows the numbers and
/// nothing else — editing happens on the phone.
public struct WatchPlanView: View {
    private let plan: NutritionPlan
    private let unitSystem: UnitSystem

    public init(plan: NutritionPlan, unitSystem: UnitSystem = .metric) {
        self.plan = plan
        self.unitSystem = unitSystem
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                MacroRing(macros: plan.macros, lineWidth: 12)
                    .frame(height: 108)

                MacroLegend(macros: plan.macros)

                Divider()

                StatRow("Fiber", value: Display.grams(plan.macros.fiberGrams))
                StatRow("Water", value: Display.volume(plan.macros.waterML, in: unitSystem))

                if abs(plan.energy.dailyDelta) >= 1 {
                    let delta = plan.energy.dailyDelta
                    StatRow(
                        delta < 0 ? "Deficit" : "Surplus",
                        value: "\(Display.signedCalories(delta)) kcal",
                        tint: delta < 0 ? Senku.Palette.deficit : Senku.Palette.surplus
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(plan.energy.goal.title)
    }
}
#endif
