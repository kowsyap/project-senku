import SwiftUI
import SenkuCore

/// A donut showing how the day's calories split across the three macros.
///
/// Segments are drawn from the macros' *calorie* shares rather than their gram
/// counts — a gram of fat carries more than twice the energy of a gram of
/// protein, so a gram-proportional ring would be a lie.
public struct MacroRing: View {
    private let macros: MacroTargets
    private let lineWidth: CGFloat

    public init(macros: MacroTargets, lineWidth: CGFloat = Senku.Metrics.ringWidth) {
        self.macros = macros
        self.lineWidth = lineWidth
    }

    private struct Segment {
        let color: Color
        let start: Double
        let end: Double
    }

    private var segments: [Segment] {
        let total = macros.proteinCalories + macros.carbCalories + macros.fatCalories
        guard total > 0 else { return [] }

        let fractions: [(Color, Double)] = [
            (Senku.Palette.protein, macros.proteinCalories / total),
            (Senku.Palette.carbs, macros.carbCalories / total),
            (Senku.Palette.fat, macros.fatCalories / total),
        ]

        var cursor = 0.0
        return fractions.map { color, fraction in
            defer { cursor += fraction }
            return Segment(color: color, start: cursor, end: cursor + fraction)
        }
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)

            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }
            .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(Display.calories(macros.calories))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(lineWidth + 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily target")
        .accessibilityValue(
            """
            \(Display.calories(macros.calories)) calories. \
            Protein \(Display.grams(macros.proteinGrams)). \
            Carbohydrate \(Display.grams(macros.carbGrams)). \
            Fat \(Display.grams(macros.fatGrams)).
            """
        )
    }
}

/// The legend that accompanies `MacroRing`.
public struct MacroLegend: View {
    private let macros: MacroTargets

    public init(macros: MacroTargets) {
        self.macros = macros
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Protein", Senku.Palette.protein, macros.proteinGrams, macros.proteinPercentage)
            row("Carbs", Senku.Palette.carbs, macros.carbGrams, macros.carbPercentage)
            row("Fat", Senku.Palette.fat, macros.fatGrams, macros.fatPercentage)
        }
    }

    private func row(_ label: String, _ color: Color, _ grams: Double, _ percent: Double) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            Text(label)
                .font(.subheadline)

            Spacer(minLength: 6)

            Text(Display.grams(grams))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()

            Text(Display.percent(percent))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
