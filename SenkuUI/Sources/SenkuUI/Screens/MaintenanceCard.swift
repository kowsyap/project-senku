#if !os(watchOS)
import SwiftUI
import SenkuCore

/// What the scale says you burn, against what the formula assumed.
///
/// On the Me page, after the plan it would change: it is a claim about your
/// body's maintenance figure, which is what every target there is built on.
///
/// Offered, never applied. The app is telling you its own formula was wrong
/// about you, which is worth saying — and is still a claim built on
/// self-reported eating, so the decision stays yours.
struct MaintenanceCard: View {
    let profile: ProfileStore.Profile
    let weights: WeightLogStore
    let intake: IntakeStore
    let unitSystem: UnitSystem
    /// The measured figure to plan from, or nil to go back to the formula.
    let onAdopt: (Double?) -> Void

    var body: some View {
        if let measured = profile.measuredMaintenanceCalories {
            Card("Maintenance") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(measured.rounded()).formatted())")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Senku.Palette.surplus)
                        Text("kcal, measured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Your targets come from what the scale did, not from the formula.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Use the formula instead") { onAdopt(nil) }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Senku.Palette.deficit)
                }
            }
        } else if let finding = MaintenanceCheck.finding(
                      profile: profile,
                      weights: weights,
                      intake: intake
                  ) {
            Card("Maintenance") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(
                        "Over \(finding.loggedDays) logged days you averaged "
                        + "\(Int(finding.estimate.intakeCalories.rounded()).formatted()) kcal and the scale "
                        + (finding.estimate.observedWeeklyChangeKG < 0 ? "fell" : "rose")
                        + " \(Display.mass(abs(finding.estimate.observedWeeklyChangeKG), in: unitSystem)) a week."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("MEASURED")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.tertiary)
                            Text("\(Int(finding.measured).formatted())")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Senku.Palette.surplus)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text("FORMULA")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.tertiary)
                            Text("\(Int(finding.formula).formatted())")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Color.secondary)
                        }

                        Spacer(minLength: 0)
                    }

                    Text(finding.burnsMore
                         ? "You burn about \(Int(abs(finding.difference).rounded())) kcal more a day than the formula assumed."
                         : "You burn about \(Int(abs(finding.difference).rounded())) kcal less a day than the formula assumed.")
                        .font(.caption)
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
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
    }
}
#endif
