#if os(iOS)
import SwiftUI
import SenkuCore

/// Food on the Home Screen: two rings and the two figures behind them.
///
/// The phone screen's arrangement and the watch's, at a widget's size —
/// calories outside, protein inside, the protein figure in the middle. Three
/// places showing the same pair of rings means one glance is learned once.
///
/// ## Why this one has no buttons
///
/// The water widget logs a drink, because a drink is one tap and one number
/// everybody already knows. Food is not: a meal is a name and three macros, and
/// a widget that could only add "some protein" would be guessing on your behalf
/// into the figure the whole feature exists to keep honest. So this one reports
/// and opens the app, which is the honest division of labour.
public struct FoodWidgetView: View {
    public enum Size { case small, medium }

    private let summary: IntakeSummary
    private let size: Size

    public init(summary: IntakeSummary, size: Size) {
        self.summary = summary
        self.size = size
    }

    private var calorieTint: Color {
        guard summary.calorieTarget > 0 else { return Senku.Palette.carbs }
        if summary.isOverCalories { return Senku.Palette.warning }
        return summary.isCaloriesMet ? Senku.Palette.surplus : Senku.Palette.carbs
    }

    private var proteinTint: Color {
        summary.isProteinMet ? Senku.Palette.surplus : Senku.Palette.protein
    }

    public var body: some View {
        if summary.hasTargets {
            switch size {
            case .small: small
            case .medium: medium
            }
        } else {
            // No profile, no targets, and two rings drawn against numbers
            // nobody chose would be worse than saying so.
            VStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.title3)
                    .foregroundStyle(Senku.Palette.protein)
                Text("Set your targets")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var small: some View {
        VStack(spacing: 5) {
            rings
                .frame(maxHeight: .infinity)

            calorieLine
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            rings
                .frame(width: 104)

            VStack(alignment: .leading, spacing: 8) {
                figure(
                    "Protein",
                    tint: proteinTint,
                    value: Display.tidyGrams(summary.proteinG),
                    detail: summary.isProteinMet
                        ? "target met"
                        : "\(Display.tidyGrams(summary.proteinRemainingG)) to go"
                )

                figure(
                    "Calories",
                    tint: calorieTint,
                    value: "\(Int(summary.calories.rounded()).formatted())",
                    detail: summary.calories > summary.calorieTarget
                        ? "\(Int((summary.calories - summary.calorieTarget).rounded())) over"
                        : "\(Int(summary.caloriesRemaining.rounded())) to go"
                )
            }

            Spacer(minLength: 0)
        }
    }

    private func figure(_ title: String, tint: Color, value: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
    }

    private var rings: some View {
        ZStack {
            ring(fraction: summary.calorieFraction, tint: calorieTint, width: 9)

            ring(fraction: summary.proteinFraction, tint: proteinTint, width: 7)
                .padding(12)

            VStack(spacing: -2) {
                Text(Display.gramsValue(summary.proteinG))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(proteinTint)
                Text("g")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Food today")
        .accessibilityValue(
            "\(Int(summary.proteinG.rounded())) of \(Int(summary.proteinTargetG)) grams protein,"
            + " \(Int(summary.calories.rounded())) of \(Int(summary.calorieTarget)) calories"
        )
    }

    private func ring(fraction: Double, tint: Color, width: CGFloat) -> some View {
        ZStack {
            Circle().stroke(.quaternary.opacity(0.6), lineWidth: width)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    /// The figure the rings cannot carry: the inner one already has protein in
    /// the middle of it, so calories go underneath.
    private var calorieLine: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(calorieTint)
                .frame(width: 6, height: 6)

            Text("\(Int(summary.calories.rounded()).formatted())")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("/ \(Int(summary.calorieTarget.rounded()).formatted())")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityHidden(true)
    }
}
#endif
