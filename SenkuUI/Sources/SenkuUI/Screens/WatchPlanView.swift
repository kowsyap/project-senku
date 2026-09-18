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
        // No ScrollView. Everything a plan is — the ring, the three macros,
        // fibre, water and the deficit — fits one watch screen if it is laid
        // out for one, and a target you have to scroll to reach is a target you
        // check less often. The two small figures share a row rather than
        // taking one each.
        VStack(spacing: 7) {
            MacroRing(macros: plan.macros, lineWidth: 9)
                .frame(height: 86)

            MacroLegend(macros: plan.macros)

            HStack(spacing: 10) {
                small("Fiber", Display.grams(plan.macros.fiberGrams), .secondary)
                small("Water", Display.millilitres(plan.macros.waterML), .secondary)
            }

            if abs(plan.energy.dailyDelta) >= 1 {
                let delta = plan.energy.dailyDelta
                small(
                    delta < 0 ? "Deficit" : "Surplus",
                    "\(Display.signedCalories(delta)) kcal",
                    delta < 0 ? Senku.Palette.deficit : Senku.Palette.surplus
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
    }

    /// A label over its figure, sized for a row that has to share the width.
    private func small(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: -1) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
