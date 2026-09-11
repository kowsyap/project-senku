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

            HStack {
                Text("Age")
                    .font(.subheadline)
                Spacer(minLength: 8)
                NumericField(
                    value: Binding(
                        get: { Double(draft.age) },
                        set: { draft.age = Int($0.rounded()) }
                    ),
                    range: 13...120,
                    unit: "years",
                    width: 52
                )
                Stepper("Age", value: $draft.age, in: 13...120)
                    .labelsHidden()
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
                decimals: 0,
                unit: "cm"
            )
        case .imperial:
            HStack {
                Text("Height")
                    .font(.subheadline)
                Spacer(minLength: 8)
                NumericField(
                    value: Binding(
                        get: { Double(draft.heightFeet) },
                        set: { draft.heightFeet = Int($0.rounded()) }
                    ),
                    range: 3...8,
                    unit: "ft",
                    width: 40
                )
                NumericField(
                    value: Binding(
                        get: { draft.heightInches },
                        set: { draft.heightInches = $0 }
                    ),
                    range: 0...11,
                    unit: "in",
                    width: 40
                )
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
            decimals: draft.unitSystem == .metric ? 1 : 0,
            unit: draft.unitSystem.massLabel
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
                decimals: 1,
                unit: "%"
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

/// A slider paired with a field, so a value can be dragged or typed.
///
/// The slider is for exploring, the field for entering a number you already
/// know — asking someone to land 82.5 kg on a slider is needless work.
struct SliderField: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var decimals: Int = 0
    var unit: String?

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer(minLength: 8)
                NumericField(value: $value, range: range, decimals: decimals, unit: unit)
            }
            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(label)
                .accessibilityValue(String(format: "%.\(decimals)f \(unit ?? "")", value))
        }
    }
}
#endif
