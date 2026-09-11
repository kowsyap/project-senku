import SwiftUI
import SenkuCore

public struct TargetsView: View {
    /// Which layout to draw. The widget passes its family through rather than
    /// reading the environment, so this renders offscreen too — `senku-render`
    /// has no widget environment to supply.
    public enum Size { case small, medium }

    private let size: Size
    private let profile: ProfileStore.Profile?

    public init(profile: ProfileStore.Profile?, size: Size = .small) {
        self.profile = profile
        self.size = size
    }

    public var body: some View {
        if let plan = profile?.plan {
            switch size {
            case .medium: medium(plan)
            case .small: small(plan)
            }
        } else {
            empty
        }
    }

    /// `showsMacros` is off for the medium layout, which lists them with
    /// labels alongside — the compact colour-only line would just repeat it.
    private func small(_ plan: NutritionPlan, showsMacros: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("TARGET")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(Display.calories(plan.macros.calories))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("kcal")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            if showsMacros {
                macroLine(plan)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func medium(_ plan: NutritionPlan) -> some View {
        HStack(spacing: 14) {
            small(plan, showsMacros: false)

            VStack(alignment: .leading, spacing: 6) {
                macroRow("Protein", plan.macros.proteinGrams, Senku.Palette.protein)
                macroRow("Carbs", plan.macros.carbGrams, Senku.Palette.carbs)
                macroRow("Fat", plan.macros.fatGrams, Senku.Palette.fat)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The compact form: three coloured grams, no labels. At this size the
    /// colours carry the meaning and the words would only cost legibility.
    private func macroLine(_ plan: NutritionPlan) -> some View {
        HStack(spacing: 6) {
            grams(plan.macros.proteinGrams, Senku.Palette.protein)
            grams(plan.macros.carbGrams, Senku.Palette.carbs)
            grams(plan.macros.fatGrams, Senku.Palette.fat)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            """
            Protein \(Display.grams(plan.macros.proteinGrams)), \
            carbohydrate \(Display.grams(plan.macros.carbGrams)), \
            fat \(Display.grams(plan.macros.fatGrams))
            """
        )
    }

    private func grams(_ value: Double, _ color: Color) -> some View {
        Text(Display.grams(value))
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func macroRow(_ label: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
            Spacer(minLength: 4)
            Text(Display.grams(value))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "person.crop.circle.dashed")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No profile yet")
                .font(.caption.weight(.semibold))
            Text("Save one in Senku.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
