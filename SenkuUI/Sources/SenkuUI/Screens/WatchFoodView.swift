#if os(watchOS)
import SwiftUI
import SenkuCore

/// Food, on a watch: two rings and two buttons.
///
/// Calories on the outside, protein inside — the phone's arrangement, at a
/// wrist's size, so the same glance means the same thing on either device.
/// Everything else about food lives on the phone: the meals, the quick-adds,
/// the streaks, the arithmetic behind the targets. What a wrist is for is the
/// figure and the one action.
///
/// ## Why only protein and calories
///
/// Because those are the two things you can know without a form. A shake is 30
/// grams; dinner was about seven hundred. Carbs and fat are typed from a packet
/// you are holding, which means you are already somewhere with a phone — and
/// four crown-driven fields on a 40 mm screen is a chore nobody completes.
///
/// The total shown is the phone's, plus anything logged here that the phone has
/// not confirmed yet. Waiting for the round trip would leave the rings still
/// while the phone sleeps, and a button that appears to do nothing gets pressed
/// twice.
public struct WatchFoodView: View {
    private let summary: IntakeSummary
    private let pendingProteinG: Double
    private let pendingCalories: Double
    private let onLog: (Double, Double) -> Void

    @State private var logging: Field?

    /// Which number the sheet is asking for.
    private enum Field: String, Identifiable {
        case protein, calories
        var id: String { rawValue }
    }

    public init(
        summary: IntakeSummary,
        pendingProteinG: Double,
        pendingCalories: Double,
        onLog: @escaping (Double, Double) -> Void
    ) {
        self.summary = summary
        self.pendingProteinG = pendingProteinG
        self.pendingCalories = pendingCalories
        self.onLog = onLog
    }

    private var proteinG: Double { summary.proteinG + pendingProteinG }
    private var calories: Double { summary.calories + pendingCalories }

    private var proteinFraction: Double {
        guard summary.proteinTargetG > 0 else { return 0 }
        return min(1, proteinG / summary.proteinTargetG)
    }

    private var calorieFraction: Double {
        guard summary.calorieTarget > 0 else { return 0 }
        return min(1, calories / summary.calorieTarget)
    }

    private var isProteinMet: Bool {
        summary.proteinTargetG > 0 && proteinG >= summary.proteinTargetG
    }

    private var calorieTint: Color {
        guard summary.calorieTarget > 0 else { return Senku.Palette.carbs }
        let over = calories - summary.calorieTarget
        if over > summary.calorieTarget * IntakeDay.calorieTolerance { return Senku.Palette.warning }
        if abs(over) <= summary.calorieTarget * IntakeDay.calorieTolerance && calories > 0 {
            return Senku.Palette.surplus
        }
        return Senku.Palette.carbs
    }

    public var body: some View {
        Group {
            if summary.hasTargets {
                logged
            } else {
                // No profile on the phone means no targets, and two rings drawn
                // against numbers nobody chose would be worse than this line.
                VStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.title3)
                        .foregroundStyle(Senku.Palette.protein)
                    Text("Set your targets on the phone")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }
        }
        .sheet(item: $logging) { field in
            WatchFoodEditor(
                title: field == .protein ? "Protein" : "Calories",
                unit: field == .protein ? "g" : "kcal",
                tint: field == .protein ? Senku.Palette.protein : Senku.Palette.carbs,
                start: field == .protein ? 30 : 400,
                range: field == .protein ? 0 ... 300 : 0 ... 3000,
                step: 5
            ) { value in
                onLog(
                    field == .protein ? value : 0,
                    field == .calories ? value : 0
                )
                logging = nil
            } onCancel: {
                logging = nil
            }
        }
    }

    private var logged: some View {
        GeometryReader { proxy in
            VStack(spacing: 6) {
                rings
                    .frame(height: proxy.size.height * 0.52)

                figures

                buttons
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.horizontal, 6)
    }

    private var rings: some View {
        ZStack {
            ring(fraction: calorieFraction, tint: calorieTint, width: 9)

            ring(
                fraction: proteinFraction,
                tint: isProteinMet ? Senku.Palette.surplus : Senku.Palette.protein,
                width: 8
            )
            .padding(12)

            VStack(spacing: -2) {
                Text(Display.gramsValue(proteinG))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(isProteinMet ? Senku.Palette.surplus : Senku.Palette.protein)
                Text("g")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Food today")
        .accessibilityValue(
            "\(Int(proteinG.rounded())) of \(Int(summary.proteinTargetG)) grams protein,"
            + " \(Int(calories.rounded())) of \(Int(summary.calorieTarget)) calories"
        )
    }

    private func ring(fraction: Double, tint: Color, width: CGFloat) -> some View {
        ZStack {
            Circle().stroke(.quaternary.opacity(0.5), lineWidth: width)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy(duration: 0.3), value: fraction)
        }
    }

    /// The calorie figure, which the rings cannot say — the inner ring already
    /// has the protein number in the middle of it.
    private var figures: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(calorieTint)
                .frame(width: 6, height: 6)

            Text("\(Int(calories.rounded()))")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("/ \(Int(summary.calorieTarget.rounded())) kcal")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityHidden(true)
    }

    private var buttons: some View {
        HStack(spacing: 6) {
            logButton("Protein", tint: Senku.Palette.protein) { logging = .protein }
            logButton("kcal", tint: Senku.Palette.carbs) { logging = .calories }
        }
    }

    private func logButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(tint.opacity(0.22), in: .rect(cornerRadius: 9))
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log \(title)")
    }
}

/// One number, turned in with the crown.
///
/// The same decision as the weigh-in editor: typing on a watch is a chore, and
/// every figure this asks for is a round one you already know.
///
/// Five at a time, both of them. A meal is guessed rather than weighed — you
/// land on "about 700" and then want it a little higher — and five is the step
/// that refines a guess without overshooting it. One would be a hundred and
/// forty clicks to reach seven hundred; fifty would jump past the number you
/// meant.
private struct WatchFoodEditor: View {
    let title: String
    let unit: String
    let tint: Color
    let range: ClosedRange<Double>
    let step: Double
    let onSave: (Double) -> Void
    let onCancel: () -> Void

    @State private var value: Double

    init(
        title: String,
        unit: String,
        tint: Color,
        start: Double,
        range: ClosedRange<Double>,
        step: Double,
        onSave: @escaping (Double) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.unit = unit
        self.tint = tint
        self.range = range
        self.step = step
        self.onSave = onSave
        self.onCancel = onCancel
        _value = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("\(Int(value)) \(unit)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(tint)
                    .focusable()
                    .digitalCrownRotation(
                        $value,
                        from: range.lowerBound,
                        through: range.upperBound,
                        by: step,
                        sensitivity: .medium
                    )

                Button("Add") { onSave(value) }
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                    .disabled(value <= 0)
            }
            .padding(.horizontal, 6)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
#endif
