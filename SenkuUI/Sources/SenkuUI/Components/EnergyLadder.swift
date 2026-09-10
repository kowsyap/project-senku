import SwiftUI
import SenkuCore

/// Maintenance calories at every activity level, as a set of proportional bars.
///
/// Showing the whole ladder rather than a single number is the point: it makes
/// visible how much changing your training actually moves the target, and it
/// lets someone sanity-check the level they picked.
public struct EnergyLadder: View {
    private let energy: EnergyProfile

    public init(energy: EnergyProfile) {
        self.energy = energy
    }

    private var maximum: Double {
        max(energy.expenditure(at: .athlete), 1)
    }

    public var body: some View {
        VStack(spacing: 8) {
            ForEach(ActivityLevel.allCases) { level in
                let value = energy.expenditure(at: level)
                let isSelected = level == energy.activityLevel

                HStack(spacing: 10) {
                    Text(level.title)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .frame(width: 112, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.quaternary.opacity(0.5))
                            Capsule()
                                .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                                .frame(width: max(4, geometry.size.width * value / maximum))
                        }
                    }
                    .frame(height: 10)

                    Text(Display.calories(value))
                        .font(.caption.weight(isSelected ? .semibold : .regular))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .frame(width: 44, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(level.title)
                .accessibilityValue(
                    "\(Display.calories(value)) calories\(isSelected ? ", your selected level" : "")"
                )
            }
        }
    }
}
