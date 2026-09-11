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
    private let onSave: (ProfileStore.Profile) -> Void

    @State private var editingDraft: PlanDraft?

    public init(
        profile: ProfileStore.Profile,
        onSave: @escaping (ProfileStore.Profile) -> Void
    ) {
        self.profile = profile
        self.onSave = onSave
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                ResultsView(plan: profile.plan, unitSystem: profile.unitSystem)
                lastUpdated
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .toolbar {
            ToolbarItem {
                Button("Edit", systemImage: "slider.horizontal.3") {
                    editingDraft = PlanDraft(profile: profile)
                }
            }
        }
        .sheet(item: $editingDraft) { draft in
            ProfileEditorSheet(draft: draft) { updated in
                onSave(updated)
                editingDraft = nil
            } onCancel: {
                editingDraft = nil
            }
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
private struct ProfileEditorSheet: View {
    @Bindable var draft: PlanDraft
    let onSave: (ProfileStore.Profile) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Senku.Metrics.stackSpacing) {
                    livePreview
                    PlanInputForm(draft: draft)
                }
                .padding()
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(.background)
            .navigationTitle("Edit profile")
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
