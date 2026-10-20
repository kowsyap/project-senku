#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Your saved numbers, at a glance.
///
/// Deliberately *not* a calculator. You already worked these out; opening this
/// tab should answer "what is my protein target" without making you look at a
/// slider first. Editing is there when you want it, one tap away.
public struct ProfileDashboardView: View {
    private let profile: ProfileStore.Profile
    private let weights: WeightLogStore?
    private let intake: IntakeStore?
    private let onAdoptMaintenance: ((Double?) -> Void)?
    private let onSave: (ProfileStore.Profile) -> Void

    @State private var editingDraft: PlanDraft?
    /// Shared by the card wherever it is drawn, so a decision made on it is
    /// seen at once.
    @State private var cycle = MaintenanceCycleStore()

    public init(
        profile: ProfileStore.Profile,
        weights: WeightLogStore? = nil,
        intake: IntakeStore? = nil,
        onAdoptMaintenance: ((Double?) -> Void)? = nil,
        onSave: @escaping (ProfileStore.Profile) -> Void
    ) {
        self.profile = profile
        self.weights = weights
        self.intake = intake
        self.onAdoptMaintenance = onAdoptMaintenance
        self.onSave = onSave
    }

    private var maintenance: MaintenanceCheck.Result? {
        guard let weights, let intake, onAdoptMaintenance != nil else { return nil }
        return MaintenanceCheck.check(profile: profile, weights: weights, intake: intake, since: cycle.start)
    }

    public var body: some View {
        let maintenance = maintenance

        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                // A suggestion waiting on a decision goes first, where it is
                // seen; the count goes after the plan, out of the way.
                if let maintenance, maintenance.isReady {
                    maintenanceCard(maintenance)
                }

                detailsCard
                ResultsView(
                    plan: profile.plan,
                    unitSystem: profile.unitSystem,
                    showsAdvisories: false,
                    calculatorPlan: profile.hasAdjustments ? profile.calculatorPlan : nil
                )

                if let maintenance, !maintenance.isReady {
                    maintenanceCard(maintenance)
                }

                // The notes on the plan, last: read once the numbers are known.
                ForEach(profile.plan.bannerAdvisories) { advisory in
                    AdvisoryBanner(advisory)
                }

                lastUpdated
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .onAppear {
            cycle.reload()
            // A fortnight that came out on track is settled; save that, so a
            // later change to the profile cannot reopen it.
            if let start = maintenance?.cycleStart { cycle.advance(to: start) }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    editingDraft = PlanDraft(profile: profile)
                } label: {
                    StackedActionLabel("Edit", symbol: "slider.horizontal.3")
                }
                .accessibilityLabel("Edit Profile")
            }
        }
        .sheet(item: $editingDraft) { draft in
            ProfileEditorSheet(draft: draft) { updated in
                var updated = updated
                updated.keepFormlessFields(of: profile)
                onSave(updated)
                editingDraft = nil
            } onCancel: {
                editingDraft = nil
            }
        }
    }

    private func maintenanceCard(_ result: MaintenanceCheck.Result) -> some View {
        MaintenanceCard(
            profile: profile,
            result: result,
            cycle: cycle,
            unitSystem: profile.unitSystem,
            onAdopt: { onAdoptMaintenance?($0) }
        )
    }

    /// What the plan was worked out from, spelled out.
    ///
    /// First on the screen rather than under the results, which are long enough
    /// that anything below them is found only by someone who already knows it
    /// is there. It also reads in the right order: who this is, then what they
    /// should eat.
    private var detailsCard: some View {
        Card("About you") {
            StatRow("Name", value: profile.name ?? "—")
            StatRow("Sex", value: profile.metrics.sex.rawValue.capitalized)
            StatRow("Age", value: "\(profile.metrics.age)")
            StatRow("Height", value: Display.height(profile.metrics.heightCM, in: profile.unitSystem))
            StatRow("Weight", value: Display.mass(profile.metrics.weightKG, in: profile.unitSystem))

            // No "estimated" note: the advisory card above already says the
            // figure is a BMI estimate and what measuring it would buy, and
            // saying it twice on one screen reads as two different warnings.
            StatRow(
                "Body fat",
                value: Display.percent(profile.metrics.effectiveBodyFatPercentage)
            )

            Divider()

            StatRow("Activity", value: profile.activityLevel.title, detail: profile.activityLevel.detail)
            StatRow("Goal", value: profile.goal.title)
            goalWeightRow
            StatRow("Formula", value: profile.plan.energy.formulaUsed.title)
        }
    }

    @ViewBuilder
    private var goalWeightRow: some View {
        if let goalWeightKG = profile.goalWeightKG {
            StatRow(
                "Goal weight",
                value: Display.mass(goalWeightKG, in: profile.unitSystem),
                detail: Display.duration(weeks: profile.weeksToGoalWeight).map { "\($0) at this rate" }
                    ?? "This goal does not move you towards it",
                tint: Senku.Palette.protein
            )
        }
    }

    private var lastUpdated: some View {
        Text("Updated \(profile.updatedAt.formatted(.relative(presentation: .named)))")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
    }
}

/// The profile editor. Shows the target updating live while you change inputs,
/// so the effect of a change is visible before you commit to it.
struct ProfileEditorSheet: View {
    @Bindable var draft: PlanDraft
    var title: String = "Edit Profile"
    let onSave: (ProfileStore.Profile) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Senku.Metrics.stackSpacing) {
                    livePreview
                    PlanInputForm(draft: draft, includesName: true)
                }
                .padding()
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(.background)
            .dismissableKeyboard()
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let snapshot = draft.profileSnapshot {
                            onSave(snapshot)
                        }
                    }
                    .disabled(draft.profileSnapshot == nil)
                }
            }
        }
    }

    @ViewBuilder
    private var livePreview: some View {
        if let plan = draft.plan {
            Card(plan.energy.goal.title) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Display.calories(plan.macros.calories))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("kcal a day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                MacroLegend(macros: plan.macros)
            }
            .animation(.snappy(duration: 0.2), value: plan.macros.calories)
        } else if let message = draft.validationMessage {
            Card {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
