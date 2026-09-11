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

    /// Saving is offered only while there is no profile to overwrite. Once one
    /// exists, this tab is purely for other people's numbers and the Me tab is
    /// where your own get edited.
    private let offersSaving: Bool
    private let onSave: ((ProfileStore.Profile) -> Void)?

    public init(
        draft: PlanDraft = PlanDraft(),
        offersSaving: Bool = true,
        onSave: ((ProfileStore.Profile) -> Void)? = nil
    ) {
        _draft = State(initialValue: draft)
        self.offersSaving = offersSaving
        self.onSave = onSave
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                PlanInputForm(draft: draft)

                if let plan = draft.plan {
                    ResultsView(plan: plan, unitSystem: draft.unitSystem)

                    if offersSaving, let onSave, let snapshot = draft.profileSnapshot {
                        Button {
                            onSave(snapshot)
                        } label: {
                            Label("Save as my profile", systemImage: "person.crop.circle.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
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
        .animation(.snappy(duration: 0.2), value: draft.goal)
        .animation(.snappy(duration: 0.2), value: draft.activityLevel)
    }

}

#Preview("Quick calc") {
    NavigationStack {
        CalculatorView(draft: PlanDraft(goal: .moderateCut)) { _ in }
            .navigationTitle("Quick calc")
    }
}
#endif
