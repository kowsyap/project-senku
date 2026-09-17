import SwiftUI
import SenkuCore

/// Today's targets, for the Home Screen.
///
/// The same ring the app draws, because a widget that restates the app in a
/// different visual language makes you translate between them at a glance —
/// which is the one thing a glance cannot afford. `MacroRing` carries the
/// calorie total in its middle, so the headline number and the split it is made
/// of are one object rather than two.
///
/// Every figure is labelled. The previous version left the three macro grams as
/// bare coloured numbers, on the theory that the colours carried the meaning;
/// they do in the app, where a legend sits under the ring, and they do not on a
/// Home Screen seen in passing.
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

    private var unitSystem: UnitSystem { profile?.unitSystem ?? .metric }

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

    // MARK: - Small

    private func small(_ plan: NutritionPlan) -> some View {
        VStack(spacing: 6) {
            MacroRing(macros: plan.macros, lineWidth: 8)
                .frame(maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)

            HStack(spacing: 2) {
                figure(Display.compactGrams(plan.macros.proteinGrams), "protein", Senku.Palette.protein)
                figure(Display.compactGrams(plan.macros.carbGrams), "carbs", Senku.Palette.carbs)
                figure(Display.compactGrams(plan.macros.fatGrams), "fat", Senku.Palette.fat)
                figure(
                    Display.compactVolume(plan.macros.waterML, in: unitSystem)
                        .replacingOccurrences(of: " ", with: ""),
                    "water",
                    Senku.Palette.deficit
                )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(plan))
    }

    /// A number with what it is written underneath, small.
    ///
    /// No `minimumScaleFactor` here, deliberately. It shrinks each `Text`
    /// independently to whatever fits, so four columns of different-length
    /// numbers come out at four different sizes — which reads as a mistake,
    /// because it is one. The type is sized to fit the longest value instead,
    /// and every column keeps it.
    private func figure(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Medium

    private func medium(_ plan: NutritionPlan) -> some View {
        HStack(spacing: 16) {
            MacroRing(macros: plan.macros, lineWidth: 10)
                .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 5) {
                row("Protein", Display.grams(plan.macros.proteinGrams), Senku.Palette.protein)
                row("Carbs", Display.grams(plan.macros.carbGrams), Senku.Palette.carbs)
                row("Fat", Display.grams(plan.macros.fatGrams), Senku.Palette.fat)
                Divider()
                row("Water", Display.volume(plan.macros.waterML, in: unitSystem), Senku.Palette.deficit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(plan))
    }

    private func row(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
            Spacer(minLength: 4)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    /// One sentence for VoiceOver, rather than eight separate stops through
    /// numbers whose labels are two points tall.
    private func spoken(_ plan: NutritionPlan) -> String {
        """
        \(Display.calories(plan.macros.calories)) calories. \
        Protein \(Display.grams(plan.macros.proteinGrams)), \
        carbohydrate \(Display.grams(plan.macros.carbGrams)), \
        fat \(Display.grams(plan.macros.fatGrams)), \
        water \(Display.volume(plan.macros.waterML, in: unitSystem)).
        """
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
