#if !os(watchOS)
import SwiftUI
import SenkuCore

/// What the scale says you burn, against what the plan is using.
///
/// Two states. While counting, only how long until there is something to say
/// — no figure, because there is not one yet worth reading. From fourteen
/// complete days in a row, if they disagree with the plan, the measured figure
/// with a button to use it and a ✕ to pass; either starts the count again. See
/// ``MaintenanceCheck``.
///
/// The Me page puts a suggestion at the top, where it will be seen, and the
/// count further down, where it will not be in the way.
///
/// Offered, never applied: it is still a claim built on self-reported eating,
/// so the decision stays yours.
struct MaintenanceCard: View {
    let profile: ProfileStore.Profile
    let result: MaintenanceCheck.Result
    let cycle: MaintenanceCycleStore
    let unitSystem: UnitSystem
    /// The measured figure to plan from, or nil to go back to the formula.
    let onAdopt: (Double?) -> Void

    var body: some View {
        Card("Maintenance") {
            switch result.status {
            case let .counting(days, weighedToday, ateToday):
                counting(days: days, weighedToday: weighedToday, ateToday: ateToday)
            case let .ready(finding, days):
                suggestion(finding, days: days)
            }
        }
    }

    // MARK: - Counting

    private func counting(days: Int, weighedToday: Bool, ateToday: Bool) -> some View {
        let required = MaintenanceCheck.requiredDays
        let remaining = required - days

        return VStack(alignment: .leading, spacing: 10) {
            Text("Maintenance analysis in \(remaining) \(remaining == 1 ? "day" : "days")")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 3) {
                ForEach(0 ..< required, id: \.self) { index in
                    Capsule()
                        .fill(index < days ? Senku.Palette.surplus : Color.secondary.opacity(0.18))
                        .frame(height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(days) of \(required) days")

            HStack(spacing: 14) {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                tick("Weighed", done: weighedToday)
                tick("Food logged", done: ateToday)
            }

            if profile.measuredMaintenanceCalories != nil {
                Button("Use the formula instead") {
                    cycle.restart()
                    onAdopt(nil)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Senku.Palette.deficit)
            }
        }
    }

    private func tick(_ title: String, done: Bool) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Senku.Palette.surplus : Color.secondary)
        }
        .font(.caption)
        .accessibilityValue(done ? "Done" : "Not yet")
    }

    // MARK: - A suggestion

    private func suggestion(_ finding: MaintenanceCheck.Finding, days: Int) -> some View {
        let range = "\(finding.firstDay.formatted(.dateTime.day().month(.abbreviated)))–"
            + finding.lastDay.formatted(.dateTime.day().month(.abbreviated))

        return VStack(alignment: .leading, spacing: 10) {
            Text(
                "\(range): you averaged "
                + "\(Int(finding.estimate.intakeCalories.rounded()).formatted()) kcal and the scale "
                + (finding.estimate.observedWeeklyChangeKG < 0 ? "fell" : "rose")
                + " \(Display.mass(abs(finding.estimate.observedWeeklyChangeKG), in: unitSystem)) a week."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                figure("MEASURED", finding.measured, tint: Senku.Palette.surplus)
                figure("NOW", finding.current, tint: .secondary)
                Spacer(minLength: 0)
                // Past fourteen, the figure moves with each new day until you
                // answer — worth saying, or it looks like it changed by itself.
                if days > MaintenanceCheck.requiredDays {
                    Text("\(days) days in a row")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(finding.burnsMore
                 ? "You burn about \(Int(abs(finding.difference).rounded())) kcal more a day than your plan assumes."
                 : "You burn about \(Int(abs(finding.difference).rounded())) kcal less a day than your plan assumes.")
                .font(.caption)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    cycle.restart()
                    Feedback.control()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 40)
                        .background(Color.secondary.opacity(0.15), in: .rect(cornerRadius: 11))
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Keep \(Int(finding.current).formatted()) kcal")

                Button {
                    cycle.restart()
                    onAdopt(finding.measured)
                    Feedback.control()
                } label: {
                    Text("Use \(Int(finding.measured).formatted()) kcal")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Senku.Palette.surplus, in: .rect(cornerRadius: 11))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func figure(_ label: String, _ value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.tertiary)
            Text("\(Int(value).formatted())")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
    }
}
#endif
