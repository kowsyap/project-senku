#if os(watchOS)
import SwiftUI
import SenkuCore

/// Weight, on a watch.
///
/// Three things only: what you last weighed, what you are aiming at, and a way
/// to log today's. The chart, the history and the rate live on the phone —
/// a 40 mm screen is for the number you came for, and a trend line you cannot
/// read is worse than no trend line.
///
/// The watch keeps no log of its own. A weigh-in typed here is sent to the
/// phone, which owns the history, and the phone's summary comes back the other
/// way. That avoids the one genuinely hard problem in syncing: two devices both
/// holding a list and disagreeing about it.
public struct WatchWeightView: View {
    private let summary: WeightSummary
    private let onLog: (Double) -> Void

    @State private var isLogging = false

    public init(summary: WeightSummary, onLog: @escaping (Double) -> Void) {
        self.summary = summary
        self.onLog = onLog
    }

    private var unitSystem: UnitSystem { summary.unitSystem }

    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                headline

                if let goal = summary.goalWeightKG {
                    figure(
                        "GOAL",
                        value: Display.mass(goal, in: unitSystem),
                        tint: Senku.Palette.surplus,
                        detail: toGoal(goal)
                    )
                }

                Button {
                    isLogging = true
                } label: {
                    Label("Log weight", systemImage: "plus")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Senku.Palette.protein)
            }
            .padding(.horizontal, 4)
        }
        .sheet(isPresented: $isLogging) {
            WatchWeighInEditor(
                unitSystem: unitSystem,
                suggested: summary.lastWeightKG
            ) { weightKG in
                onLog(weightKG)
                isLogging = false
            } onCancel: {
                isLogging = false
            }
        }
    }

    @ViewBuilder
    private var headline: some View {
        if let last = summary.lastWeightKG {
            figure(
                "LAST",
                value: Display.mass(last, in: unitSystem),
                tint: Senku.Palette.protein,
                detail: summary.lastLoggedAt?.formatted(.relative(presentation: .named))
            )
        } else {
            Text("No weigh-ins yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func figure(_ label: String, value: String, tint: Color, detail: String?) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(tint)
            if let detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// How far there is to go, from the trend rather than the last reading —
    /// the same figure the phone treats as your weight.
    private func toGoal(_ goal: Double) -> String? {
        guard let from = summary.trendKG ?? summary.lastWeightKG else { return nil }
        let difference = abs(from - goal)
        guard difference >= 0.1 else { return "You are there" }
        return "\(Display.mass(difference, in: unitSystem)) to go"
    }
}

/// Typing one number on a watch.
private struct WatchWeighInEditor: View {
    let unitSystem: UnitSystem
    let suggested: Double?
    let onSave: (Double) -> Void
    let onCancel: () -> Void

    @State private var value: Double

    init(
        unitSystem: UnitSystem,
        suggested: Double?,
        onSave: @escaping (Double) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.unitSystem = unitSystem
        self.suggested = suggested
        self.onSave = onSave
        self.onCancel = onCancel

        let fallback: Double = unitSystem == .metric ? 75 : 165
        let shown = suggested.map { unitSystem == .metric ? $0 : Convert.pounds(fromKilograms: $0) }
        _value = State(initialValue: shown ?? fallback)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // The crown, not a keyboard. Typing a decimal on a watch is a
                // chore, and a weigh-in is nearly always within a kilo of the
                // last one — which is what this starts at.
                Text(String(format: "%.1f %@", value, unitSystem.massLabel))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .focusable()
                    .digitalCrownRotation(
                        $value,
                        from: unitSystem == .metric ? 35 : 77,
                        through: unitSystem == .metric ? 200 : 440,
                        by: unitSystem == .metric ? 0.1 : 0.2,
                        sensitivity: .medium
                    )

                Button("Save") {
                    onSave(unitSystem == .metric ? value : Convert.kilograms(fromPounds: value))
                }
                .buttonStyle(.borderedProminent)
                .tint(Senku.Palette.protein)
            }
            .padding(.horizontal, 6)
            .navigationTitle("Weigh in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
#endif
