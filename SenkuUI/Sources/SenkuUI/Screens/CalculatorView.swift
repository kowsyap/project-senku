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
    private let saveTitle: String?
    private let onSave: ((ProfileStore.Profile) -> Void)?

    public init(
        draft: PlanDraft = PlanDraft(),
        saveTitle: String? = "Save as my profile",
        onSave: ((ProfileStore.Profile) -> Void)? = nil
    ) {
        _draft = State(initialValue: draft)
        self.saveTitle = saveTitle
        self.onSave = onSave
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                PlanInputForm(draft: draft)

                if let plan = draft.plan {
                    ResultsView(plan: plan, unitSystem: draft.unitSystem)

                    if let onSave, let saveTitle, let snapshot = draft.profileSnapshot {
                        Button {
                            onSave(snapshot)
                        } label: {
                            Label(saveTitle, systemImage: "person.crop.circle.badge.plus")
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
