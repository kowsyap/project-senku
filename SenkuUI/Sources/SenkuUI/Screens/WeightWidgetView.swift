#if os(iOS)
import SwiftUI
import SenkuCore

/// Weight on the Home Screen: the last reading, the trend, and a way in.
///
/// ## Why this one has no buttons
///
/// The water widget logs a drink from the Home Screen because a drink is a
/// choice between three fixed amounts. A weigh-in is a number you have just
/// read off a scale — 82.4, not one of three — and a widget has no way to take
/// one. A "+250" button is a whole feature; a "+0.1 kg" button is nonsense.
///
/// So this one shows and opens: the figures at a glance, and a tap that lands
/// on the weigh-in sheet with the keypad already up.
public struct WeightWidgetView: View {
    public enum Size { case small, medium }

    private let summary: WeightSummary
    private let size: Size

    public init(summary: WeightSummary, size: Size) {
        self.summary = summary
        self.size = size
    }

    private var unitSystem: UnitSystem { summary.unitSystem }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "scalemass")
                    .font(.caption)
                    .foregroundStyle(Senku.Palette.surplus)
                Text("Weight")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let last = summary.lastWeightKG {
                Text(Display.mass(last, in: unitSystem))
                    .font(.system(size: size == .medium ? 34 : 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(Senku.Palette.protein)

                if let logged = summary.lastLoggedAt {
                    Text(logged.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("No weigh-ins")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weight")
        .accessibilityValue(spoken)
    }

    @ViewBuilder
    private var footer: some View {
        // The trend, not the last reading, is the figure worth acting on — but
        // the last reading is the one you recognise, so the widget leads with
        // that and puts the trend underneath rather than the other way round.
        if let trend = summary.trendKG {
            row("Trend", Display.mass(trend, in: unitSystem), Senku.Palette.deficit)
        }

        if let goal = summary.goalWeightKG, let from = summary.trendKG ?? summary.lastWeightKG {
            let difference = abs(from - goal)
            row(
                "To goal",
                difference < 0.1 ? "there" : Display.mass(difference, in: unitSystem),
                Senku.Palette.surplus
            )
        }
    }

    private func row(_ label: String, _ value: String, _ tint: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }

    private var spoken: String {
        guard let last = summary.lastWeightKG else { return "Nothing logged" }
        var parts = [Display.mass(last, in: unitSystem)]
        if let trend = summary.trendKG {
            parts.append("trend \(Display.mass(trend, in: unitSystem))")
        }
        return parts.joined(separator: ", ")
    }
}
#endif
