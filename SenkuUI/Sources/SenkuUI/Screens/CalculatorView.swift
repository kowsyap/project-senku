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

    /// Whether the answer can be kept. The profile editor's own copy of this
    /// screen says no — it has a Save in its toolbar already.
    private let offersSaving: Bool

    /// What keeping it is called. "Save" the first time, "Update" once there is
    /// a profile the numbers would replace, because those are different acts
    /// and the button should not claim otherwise.
    private let saveTitle: String

    private let onSave: ((ProfileStore.Profile) -> Void)?

    /// Results appear only once Calculate has been pressed.
    ///
    /// They used to update live off a pre-filled form, which meant the screen
    /// opened already showing a complete plan for a person who did not exist.
    /// An answer should be something you asked for.
    @State private var hasCalculated = false

    /// The inputs as they stood when the answer on screen was worked out.
    /// Anything different means the answer is stale and Calculate comes back.
    @State private var answeredInputs: PlanDraft.Inputs?

    public init(
        draft: PlanDraft = PlanDraft(),
        offersSaving: Bool = true,
        saveTitle: String = "Save as my profile",
        onSave: ((ProfileStore.Profile) -> Void)? = nil
    ) {
        _draft = State(initialValue: draft)
        self.offersSaving = offersSaving
        self.saveTitle = saveTitle
        self.onSave = onSave
        // A draft that arrives already filled in — the profile editor's case —
        // has nothing to ask for, so it shows its results immediately.
        _hasCalculated = State(initialValue: draft.metrics != nil)
        _answeredInputs = State(initialValue: draft.metrics != nil ? draft.inputs : nil)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                PlanInputForm(draft: draft)

                // Only ever shown for numbers that are filled in but wrong —
                // a missing answer is already marked "Required" on its own row,
                // and does not need saying twice.
                if draft.isComplete, let message = draft.validationMessage {
                    Card {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if hasCalculated, let plan = draft.plan {
                    ResultsView(plan: plan, unitSystem: draft.unitSystem)
                        .id("results")
                }

            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .dismissableKeyboard()
        .toolbar { actionItem }
        .animation(.snappy(duration: 0.28), value: action)
        .animation(.snappy(duration: 0.2), value: draft.goal)
        .animation(.snappy(duration: 0.2), value: draft.activityLevel)
    }

    // MARK: - The action

    /// What the one button at the end is currently for, if anything.
    ///
    /// One button, not two stacked: at any moment there is exactly one thing
    /// worth doing — work the numbers out, or keep them.
    private enum Action: Equatable {
        case calculate
        case recalculate
        case save
    }

    private var action: Action? {
        // A change since the answer was given puts Calculate back, which is the
        // only honest response to results that no longer match the form.
        if draft.plan != nil, !hasCalculated || draft.inputs != answeredInputs {
            return hasCalculated ? .recalculate : .calculate
        }
        if hasCalculated, offersSaving, onSave != nil, draft.profileSnapshot != nil {
            return .save
        }
        return nil
    }

    /// The action lives in the navigation bar, beside where the profile screen
    /// keeps Edit — one place on every screen where the thing you can do to
    /// what you are looking at is kept, rather than a control that moves
    /// depending on how far you have scrolled.
    ///
    /// Icon only, and shown only when there is something to do: the conditions
    /// are unchanged — Calculate once the required fields are filled,
    /// Recalculate after any change to them, Save once the answer stands.
    @ToolbarContentBuilder
    private var actionItem: some ToolbarContent {
        if let action {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    perform(action)
                } label: {
                    StackedActionLabel(shortTitle, symbol: symbol)
                }
                .tint(tint)
                .accessibilityIdentifier("button.action")
                .accessibilityLabel(title)
            }
        }
    }

    private func perform(_ action: Action) {
        switch action {
        case .calculate, .recalculate:
            hasCalculated = true
            answeredInputs = draft.inputs
        case .save:
            if let snapshot = draft.profileSnapshot { onSave?(snapshot) }
        }
    }

    private var title: String {
        switch action {
        case .recalculate: "Recalculate"
        case .save: saveTitle
        default: "Calculate"
        }
    }

    /// One word beside the icon. A bare glyph in a toolbar is a guess until
    /// you tap it, and this is the one control on the screen that does
    /// something irreversible-ish — it either replaces the answer or replaces
    /// your saved profile. The full phrasing is kept for VoiceOver.
    private var shortTitle: String {
        switch action {
        case .save: "Save"
        default: "Calc"
        }
    }

    private var symbol: String {
        switch action {
        case .save: "square.and.arrow.down"
        case .recalculate: "wrench.adjustable"
        default: "wrench.adjustable"
        }
    }

    /// Blue for the answer, green for keeping it — the same green the app
    /// already uses for a surplus, so the colour means "settled", not "go".
    private var tint: Color {
        action == .save ? Senku.Palette.surplus : Senku.Palette.protein
    }

}

#Preview("Quick calc") {
    NavigationStack {
        CalculatorView(draft: PlanDraft(goal: .moderateCut)) { _ in }
            .navigationTitle("Quick calc")
    }
}
#endif
