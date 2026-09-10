#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The calculator: inputs on top, results below, recomputed as you type.
///
/// `mode` decides whether the screen offers to remember anything. In `.guest`
/// nothing is persisted and no account is implied — that is what makes the app
/// usable in a thirty-second gym conversation.
public struct CalculatorView: View {
    public enum Mode: Sendable {
        /// Someone else's numbers. Calculate, show, discard.
        case guest
        /// The owner's own profile.
        case profile
    }

    @State private var draft: PlanDraft
    private let mode: Mode
    private let onSave: ((ProfileStore.Profile) -> Void)?

    public init(
        draft: PlanDraft = PlanDraft(),
        mode: Mode = .guest,
        onSave: ((ProfileStore.Profile) -> Void)? = nil
    ) {
        _draft = State(initialValue: draft)
        self.mode = mode
        self.onSave = onSave
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                aboutYouCard
                goalCard

                if let plan = draft.plan {
                    ResultsView(plan: plan, unitSystem: draft.unitSystem)
                    if let onSave, let snapshot = draft.profileSnapshot {
                        saveButton(snapshot, action: onSave)
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

    // MARK: - Inputs

    private var aboutYouCard: some View {
        Card("About you") {
            Picker("Units", selection: $draft.unitSystem) {
                ForEach(UnitSystem.allCases) { system in
                    Text(system.title).tag(system)
                }
            }
            .pickerStyle(.segmented)

            Picker("Sex", selection: $draft.sex) {
                ForEach(Sex.allCases, id: \.self) { sex in
                    Text(sex.rawValue.capitalized).tag(sex)
                }
            }
            .pickerStyle(.segmented)

            Stepper(value: $draft.age, in: 13...120) {
                StatRow("Age", value: "\(draft.age)")
            }

            Divider()
            heightField
            Divider()
            weightField
            Divider()
            bodyFatField
        }
    }

    @ViewBuilder
    private var heightField: some View {
        switch draft.unitSystem {
        case .metric:
            SliderField(
                label: "Height",
                value: $draft.heightCM,
                range: 120...220,
                step: 1,
                display: Display.height(draft.heightCM, in: .metric)
            )
        case .imperial:
            VStack(spacing: 6) {
                StatRow("Height", value: Display.height(draft.heightCM, in: .imperial))
                HStack(spacing: 12) {
                    Stepper("Feet", value: Binding(
                        get: { draft.heightFeet },
                        set: { draft.heightFeet = $0 }
                    ), in: 3...8)
                    Stepper("Inches", value: Binding(
                        get: { Int(draft.heightInches) },
                        set: { draft.heightInches = Double($0) }
                    ), in: 0...11)
                }
                .font(.caption)
            }
        }
    }

    private var weightField: some View {
        SliderField(
            label: "Weight",
            value: draft.unitSystem == .metric
                ? $draft.weightKG
                : Binding(get: { draft.weightPounds }, set: { draft.weightPounds = $0 }),
            range: draft.unitSystem == .metric ? 35...200 : 77...440,
            step: draft.unitSystem == .metric ? 0.5 : 1,
            display: Display.mass(draft.weightKG, in: draft.unitSystem)
        )
    }

    @ViewBuilder
    private var bodyFatField: some View {
        Toggle(isOn: $draft.usesMeasuredBodyFat) {
            VStack(alignment: .leading, spacing: 1) {
                Text("I know my body fat")
                    .font(.subheadline)
                Text("Sharpens your protein target")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }

        if draft.usesMeasuredBodyFat {
            SliderField(
                label: "Body fat",
                value: $draft.bodyFatPercentage,
                range: 3...60,
                step: 0.5,
                display: Display.percent(draft.bodyFatPercentage)
            )
        }
    }

    private var goalCard: some View {
        Card("Goal") {
            Picker("Activity level", selection: $draft.activityLevel) {
                ForEach(ActivityLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            Text(draft.activityLevel.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Picker("Goal", selection: $draft.goal) {
                ForEach(Goal.allCases) { goal in
                    Text(goal.title).tag(goal)
                }
            }

            Divider()

            Picker("Formula", selection: $draft.formula) {
                ForEach(BMRFormula.allCases) { formula in
                    Text(formula.title).tag(formula)
                }
            }
            Text(formulaExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var formulaExplanation: String {
        switch draft.formula {
        case .automatic:
            draft.usesMeasuredBodyFat
                ? "Using Katch-McArdle, because you gave a measured body fat."
                : "Using Mifflin-St Jeor. Add a measured body fat to unlock Katch-McArdle."
        case .mifflinStJeor:
            "The modern default. Most accurate across the general population."
        case .katchMcArdle:
            draft.usesMeasuredBodyFat
                ? "Lean-mass based. The best choice now that body fat is known."
                : "Needs a measured body fat, so it is running on a BMI estimate."
        case .harrisBenedict:
            "The 1984 revision. Included for comparison; tends to run high."
        }
    }

    private func saveButton(
        _ profile: ProfileStore.Profile,
        action: @escaping (ProfileStore.Profile) -> Void
    ) -> some View {
        Button {
            action(profile)
        } label: {
            Label(
                mode == .guest ? "Save as my profile" : "Update my profile",
                systemImage: mode == .guest
                    ? "person.crop.circle.badge.plus"
                    : "arrow.triangle.2.circlepath"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

/// A labelled slider with its current value shown above it.
private struct SliderField: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let display: String

    var body: some View {
        VStack(spacing: 2) {
            StatRow(label, value: display)
            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(label)
                .accessibilityValue(display)
        }
    }
}

#Preview("Calculator") {
    CalculatorView(draft: PlanDraft(goal: .moderateCut), mode: .guest) { _ in }
}
#endif
