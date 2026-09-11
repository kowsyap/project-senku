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

    /// Results appear only once Calculate has been pressed.
    ///
    /// They used to update live off a pre-filled form, which meant the screen
    /// opened already showing a complete plan for a person who did not exist.
    /// An answer should be something you asked for.
    @State private var hasCalculated = false
    @State private var showsMissingFields = false

    public init(
        draft: PlanDraft = PlanDraft(),
        offersSaving: Bool = true,
        onSave: ((ProfileStore.Profile) -> Void)? = nil
    ) {
        _draft = State(initialValue: draft)
        self.offersSaving = offersSaving
        self.onSave = onSave
        // A draft that arrives already filled in — the profile editor's case —
        // has nothing to ask for, so it shows its results immediately.
        _hasCalculated = State(initialValue: draft.metrics != nil)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                PlanInputForm(draft: draft)

                calculateButton

                if showsMissingFields, let message = draft.validationMessage {
                    Card {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if hasCalculated, let plan = draft.plan {
                    ResultsView(plan: plan, unitSystem: draft.unitSystem)
                        .id("results")

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
                }
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .dismissableKeyboard()
        .onChange(of: draft.isComplete) { _, complete in
            // Stop nagging the moment the gaps are filled.
            if complete { showsMissingFields = false }
        }
        .animation(.snappy(duration: 0.2), value: draft.goal)
        .animation(.snappy(duration: 0.2), value: draft.activityLevel)
    }

    /// Deliberately always tappable, even while the form is incomplete.
    /// A disabled button says "no" without saying why; this one answers by
    /// naming what is still missing.
    private var calculateButton: some View {
        Button {
            if draft.plan != nil {
                hasCalculated = true
                showsMissingFields = false
            } else {
                hasCalculated = false
                showsMissingFields = true
            }
        } label: {
            Label(hasCalculated ? "Recalculate" : "Calculate", systemImage: "equal.square")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

#Preview("Quick calc") {
    NavigationStack {
        CalculatorView(draft: PlanDraft(goal: .moderateCut)) { _ in }
            .navigationTitle("Quick calc")
    }
}
#endif
