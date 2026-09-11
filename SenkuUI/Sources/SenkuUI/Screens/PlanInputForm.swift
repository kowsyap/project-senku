#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The inputs behind a plan: who you are, and what you are trying to do.
///
/// Shared by the quick calculator, where it is the whole screen, and by the
/// profile editor, where it sits in a sheet. Keeping it in one place means the
/// two never drift apart.
public struct PlanInputForm: View {
    @Bindable private var draft: PlanDraft

    public init(draft: PlanDraft) {
        self.draft = draft
    }

    public var body: some View {
        VStack(spacing: Senku.Metrics.stackSpacing) {
            aboutYouCard
            goalCard
        }
    }

    // MARK: - About you

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

    // MARK: - Goal

    private var goalCard: some View {
        Card("Goal") {
            // Each picker carries a visible label. Outside a `Form`, SwiftUI
            // hides a Picker's own label, which would leave three unlabelled
            // menus with no way to tell which one is which.
            LabeledContent("Activity level") {
                Picker("Activity level", selection: $draft.activityLevel) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .labelsHidden()
            }
            caption(draft.activityLevel.detail)

            Divider()

            LabeledContent("Goal") {
                Picker("Goal", selection: $draft.goal) {
                    ForEach(Goal.allCases) { goal in
                        Text(goal.title).tag(goal)
                    }
                }
                .labelsHidden()
            }
            caption(draft.goal.detail)

            Divider()

            LabeledContent("Formula") {
                Picker("Formula", selection: $draft.formula) {
                    ForEach(BMRFormula.allCases) { formula in
                        Text(formula.title).tag(formula)
                    }
                }
                .labelsHidden()
            }
            caption(formulaExplanation)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
}

/// A labelled slider with its current value shown above it.
struct SliderField: View {
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
#endif
