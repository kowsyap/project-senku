#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The quick calculator: fill in, read the answer, walk away.
///
/// This is the screen for the friend who asks a question in the gym. Nothing is
/// written to disk and no account is implied; saving is offered only as a
/// button they can ignore.
public struct CalculatorView: View {
    @State private var draft: PlanDraft
    private let replacesExistingProfile: Bool
    private let onSave: ((ProfileStore.Profile) -> Void)?

    /// Pending overwrite awaiting confirmation. Only ever set when a profile
    /// already exists, so the first save stays a single tap.
    @State private var pendingReplacement: ProfileStore.Profile?

    public init(
        draft: PlanDraft = PlanDraft(),
        replacesExistingProfile: Bool = false,
        onSave: ((ProfileStore.Profile) -> Void)? = nil
    ) {
        _draft = State(initialValue: draft)
        self.replacesExistingProfile = replacesExistingProfile
        self.onSave = onSave
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                PlanInputForm(draft: draft)

                if let plan = draft.plan {
                    ResultsView(plan: plan, unitSystem: draft.unitSystem)

                    if let onSave, let snapshot = draft.profileSnapshot {
                        saveButton(snapshot, onSave: onSave)
                    }
                } else if let message = draft.validationMessage {
                    Card {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .dismissableKeyboard()
        .confirmationDialog(
            "Replace your saved profile?",
            isPresented: Binding(
                get: { pendingReplacement != nil },
                set: { if !$0 { pendingReplacement = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingReplacement
        ) { replacement in
            Button("Replace profile", role: .destructive) {
                onSave?(replacement)
                pendingReplacement = nil
            }
            Button("Cancel", role: .cancel) { pendingReplacement = nil }
        } message: { _ in
            Text("These numbers will overwrite the ones saved on your Me tab.")
        }
        .animation(.snappy(duration: 0.2), value: draft.goal)
        .animation(.snappy(duration: 0.2), value: draft.activityLevel)
    }

    /// The first save is a single confident tap; replacing someone's existing
    /// numbers is a quieter button that asks first. Overwriting your own
    /// profile with a friend's is otherwise one stray tap away.
    @ViewBuilder
    private func saveButton(
        _ snapshot: ProfileStore.Profile,
        onSave: @escaping (ProfileStore.Profile) -> Void
    ) -> some View {
        if replacesExistingProfile {
            Button {
                pendingReplacement = snapshot
            } label: {
                Label("Replace my profile", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text("Editing your own numbers is easier on the Me tab.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            Button {
                onSave(snapshot)
            } label: {
                Label("Save as my profile", systemImage: "person.crop.circle.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

#Preview("Quick calc") {
    NavigationStack {
        CalculatorView(draft: PlanDraft(goal: .moderateCut)) { _ in }
            .navigationTitle("Quick calc")
    }
}
#endif
