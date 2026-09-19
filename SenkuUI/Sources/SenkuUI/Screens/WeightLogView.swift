#if !os(watchOS)
import SwiftUI
import Charts
import SenkuCore

/// Your weight over time, and what it implies.
///
/// The screen shows both the readings and the trend line drawn through them,
/// because the app's rule is to show its work: a single smoothed number asks to
/// be believed, while the same number over the dots it came from can be judged.
///
/// The trend is the headline, not the last reading. Day-to-day weight is mostly
/// water and food in transit, and the single most common way to abandon a plan
/// that is working is to read yesterday's dinner as fat gained.
public struct WeightLogView: View {
    @State private var store: WeightLogStore
    @State private var isAdding = false
    #if !os(watchOS)
    @State private var isShowingHistory = false
    @State private var isShowingSettings = false
    #endif
    /// Declared on every platform, because the settings page binds to it on
    /// every platform — where there are no notifications to book it simply
    /// stays false, which is cheaper than a second settings view that differs
    /// by one row.
    @State private var isReminding = {
        #if canImport(UserNotifications) && !os(macOS)
        WeightReminder.isOn
        #else
        false
        #endif
    }()

    @State private var window: Window = .threeMonths

    private let profile: ProfileStore.Profile?
    private let onAdoptWeight: ((Double) -> Void)?

    public init(
        store: WeightLogStore = WeightLogStore(),
        profile: ProfileStore.Profile?,
        onAdoptWeight: ((Double) -> Void)? = nil
    ) {
        _store = State(initialValue: store)
        self.profile = profile
        self.onAdoptWeight = onAdoptWeight
    }

    /// How much of the history the chart draws.
    ///
    /// The window clips what is *plotted*, never what is computed: the trend is
    /// always the smoothing of the whole log, clipped afterwards. Recomputing it
    /// from the window's left edge would restart the average cold and draw a
    /// jump on the first day of every window you chose.
    enum Window: String, CaseIterable, Identifiable {
        case month = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case all = "All"


        var id: String { rawValue }

        var days: Double? {
            switch self {
            case .month: 31
            case .threeMonths: 92
            case .sixMonths: 183
            case .all: nil
            }
        }
    }

    private var unitSystem: UnitSystem { profile?.unitSystem ?? UnitPreference.current }
    private var series: WeightSeries { store.series }

    private var cutoff: Date? {
        window.days.map { Date.now.addingTimeInterval(-$0 * 86_400) }
    }

    private var visibleDays: [(day: Date, weightKG: Double)] {
        guard let cutoff else { return series.dailyValues }
        return series.dailyValues.filter { $0.day >= cutoff }
    }

    private var visibleTrend: [(day: Date, weightKG: Double)] {
        guard let cutoff else { return series.trendValues }
        return series.trendValues.filter { $0.day >= cutoff }
    }

    /// The trend split wherever the log has a hole in it.
    ///
    /// Drawing one line through a month with no readings asserts a trajectory
    /// nobody measured. The maths is already honest about gaps — the decay runs
    /// over elapsed days — so this only makes the drawing agree with it.
    private var trendSegments: [[(day: Date, weightKG: Double)]] {
        let maximumGap: TimeInterval = 10 * 86_400
        var segments: [[(day: Date, weightKG: Double)]] = []
        var current: [(day: Date, weightKG: Double)] = []

        for point in visibleTrend {
            if let last = current.last, point.day.timeIntervalSince(last.day) > maximumGap {
                segments.append(current)
                current = []
            }
            current.append(point)
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }

    public var body: some View {
        Group {
            ScrollView { content }
        }
        .background(.background)
        #if canImport(UserNotifications) && !os(macOS)
        .onChange(of: isReminding) { _, wanted in
            Task {
                if wanted {
                    // Put back if permission is refused, rather than left on
                    // and silent — a switch that lies is worse than no switch.
                    let granted = await WeightReminder.enable()
                    if !granted { isReminding = false }
                } else {
                    WeightReminder.disable()
                }
            }
        }
        #endif
        .task {
            // The chart begins where the profile does, so the first reading you
            // log is a second point on a line rather than a lone dot.
            store.seedFromProfileIfNeeded(profile)

            #if canImport(UserNotifications) && !os(macOS)
            // Re-booked on every visit: a pending request can be lost to a
            // restore or to notifications being switched off and on in
            // Settings, while this screen still says it is on.
            await WeightReminder.refresh()
            #endif
        }
        .toolbar {
            #if !os(watchOS)
            ToolbarItem(placement: .primaryAction) {
                Button { isShowingSettings = true } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { isShowingHistory = true } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .disabled(store.weighIns.isEmpty)
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAdding = true
                } label: {
                    StackedActionLabel("Log", symbol: "plus")
                }
                .accessibilityLabel("Log a weigh-in")
            }
        }
        #if !os(watchOS)
        .navigationDestination(isPresented: $isShowingHistory) {
            WeightHistoryView(store: store, unitSystem: unitSystem)
        }
        .navigationDestination(isPresented: $isShowingSettings) {
            WeightSettingsView(reminding: $isReminding)
        }
        #endif
        .sheet(isPresented: $isAdding) {
            // Seeded from the last weigh-in, not the day's mean: logging 307
            // then 350 and being offered 328 next time is the app averaging
            // behind your back and calling it a suggestion.
            WeighInEditor(
                unitSystem: unitSystem,
                suggested: store.weighIns.first?.weightKG ?? profile?.metrics.weightKG
            ) {
                store.add($0)
                isAdding = false
            } onCancel: {
                isAdding = false
            }
        }
    }

    private var content: some View {
        VStack(spacing: Senku.Metrics.stackSpacing) {
            if series.isEmpty {
                empty
            } else {
                chartCard
                figuresCard
                profileNudge
            }
        }
        .padding()
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chart

    private var chartCard: some View {
        Card("Trend") {
            Picker("Range", selection: $window) {
                ForEach(Window.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Chart {
                ForEach(visibleDays, id: \.day) { entry in
                    PointMark(
                        x: .value("Day", entry.day),
                        y: .value("Weight", display(entry.weightKG))
                    )
                    .foregroundStyle(.secondary.opacity(0.5))
                    .symbolSize(18)
                }

                ForEach(Array(trendSegments.enumerated()), id: \.offset) { index, segment in
                    ForEach(segment, id: \.day) { entry in
                        LineMark(
                            x: .value("Day", entry.day),
                            y: .value("Trend", display(entry.weightKG)),
                            series: .value("Segment", index)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Senku.Palette.protein)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }

                if let goal = goalWithinView {
                    RuleMark(y: .value("Goal", display(goal)))
                        .foregroundStyle(Senku.Palette.surplus.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal")
                                .font(.caption2)
                                .foregroundStyle(Senku.Palette.surplus)
                        }
                } else if let offChart = goalOffChart {
                    // The goal is too far away to plot without flattening the
                    // readings, so it is marked at the edge it lies beyond
                    // rather than left out. Knowing it is down there, and how
                    // far, is most of what a goal line is for.
                    RuleMark(y: .value("Goal", offChart.edge))
                        .foregroundStyle(Senku.Palette.surplus.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .annotation(position: offChart.isBelow ? .bottom : .top, alignment: .leading) {
                            Text("\(offChart.isBelow ? "↓" : "↑") Goal \(Display.tidyMass(offChart.goal, in: unitSystem))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Senku.Palette.surplus)
                        }
                }
            }
            .chartYScale(domain: yDomain)
            .frame(height: 200)

            Text(chartFootnote)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var chartFootnote: String {
        let base = "Line is a 7-day half-life moving average. Each dot is a day — the average, where you weighed more than once."
        return trendSegments.count > 1
            ? base + " It breaks where you went more than ten days without weighing in."
            : base
    }

    /// The vertical range, chosen from the readings rather than left automatic.
    ///
    /// A goal eight kilos away would otherwise stretch the axis to reach it and
    /// squash three weeks of real movement into the top third of the chart —
    /// the change you are actually making, rendered as a flat line, because of
    /// a number you have not reached yet.
    private var yDomain: ClosedRange<Double> {
        let values = visibleDays.map { display($0.weightKG) }
        guard let low = values.min(), let high = values.max() else { return 0 ... 1 }

        // At least a couple of units tall, so a steady week is not magnified
        // into dramatic peaks by an axis that spans 300 grams.
        let padding = max(1, (high - low) * 0.25)
        var lower = low - padding
        var upper = high + padding

        if let goal = goalWithinView.map(display) {
            lower = min(lower, goal - 0.3)
            upper = max(upper, goal + 0.3)
        }
        return lower ... upper
    }

    /// The goal when it lies outside the plotted range: which edge it is past,
    /// and where to draw the marker so the annotation stays inside the chart.
    private var goalOffChart: (goal: Double, edge: Double, isBelow: Bool)? {
        guard let goal = profile?.goalWeightKG, goalWithinView == nil else { return nil }

        let domain = yDomain
        let inset = (domain.upperBound - domain.lowerBound) * 0.04
        let isBelow = display(goal) < domain.lowerBound
        return (
            goal: goal,
            edge: isBelow ? domain.lowerBound + inset : domain.upperBound - inset,
            isBelow: isBelow
        )
    }

    /// The goal, but only when it is close enough to belong on this chart.
    private var goalWithinView: Double? {
        guard let goal = profile?.goalWeightKG,
              let low = visibleDays.map(\.weightKG).min(),
              let high = visibleDays.map(\.weightKG).max()
        else { return nil }

        // Within a couple of kilos of what is plotted. Further than that and the
        // "To goal" row below says it better than a line off the bottom edge.
        let reach = 2.0
        return (low - reach ... high + reach).contains(goal) ? goal : nil
    }

    // MARK: - Figures

    private var figuresCard: some View {
        Card("Where you are") {
            if let trend = series.trendKG {
                StatRow(
                    "Trend",
                    value: Display.mass(trend, in: unitSystem),
                    detail: "What the app treats as your weight",
                    isProminent: true,
                    tint: Senku.Palette.protein
                )
            }

            if let newest = store.weighIns.first {
                // The literal last thing the scale said, not that day's mean.
                // The two differ whenever you weigh twice in a day, and a row
                // labelled "last reading" showing an average of two is the kind
                // of small lie that makes someone distrust the rest of it.
                StatRow(
                    "Last reading",
                    value: Display.mass(newest.weightKG, in: unitSystem),
                    detail: lastReadingDetail(newest)
                )
            }

            if let weekly = series.weeklyChangeKG {
                StatRow(
                    "Rate",
                    value: "\(Display.massDelta(weekly, in: unitSystem))/week",
                    detail: rateDetail(weekly),
                    tint: weekly < 0 ? Senku.Palette.deficit : Senku.Palette.surplus
                )
            } else {
                StatRow(
                    "Rate",
                    value: "—",
                    detail: "Two days apart is the least it takes to measure one"
                )
            }

            if let goal = profile?.goalWeightKG, let trend = series.trendKG {
                StatRow(
                    "To goal",
                    value: Display.mass(abs(trend - goal), in: unitSystem),
                    detail: goalDetail(from: trend, to: goal)
                )
            }
        }
    }

    /// When a day holds more than one weigh-in, says so and gives the figure
    /// the trend actually used.
    private func lastReadingDetail(_ newest: WeighIn) -> String {
        let when = newest.date.formatted(.relative(presentation: .named))
        let sameDay = store.weighIns.filter {
            Calendar.current.isDate($0.date, inSameDayAs: newest.date)
        }
        guard sameDay.count > 1,
              let dayValue = series.dailyValues.last?.weightKG
        else { return when }

        return "\(when) · \(sameDay.count) that day, averaged \(Display.mass(dayValue, in: unitSystem))"
    }

    /// Says what the observed rate means against the plan's own projection,
    /// rather than leaving two numbers on two screens to be compared by hand.
    private func rateDetail(_ weekly: Double) -> String {
        guard let planned = profile?.plan.projectedWeeklyChangeKG, abs(planned) > 0.01 else {
            return "Measured across every reading, not the first and last"
        }
        let difference = weekly - planned
        guard abs(difference) >= 0.1 else {
            return "Matching the plan's \(Display.massDelta(planned, in: unitSystem)) a week"
        }
        return difference < 0
            ? "Faster than the plan's \(Display.massDelta(planned, in: unitSystem)) a week"
            : "Slower than the plan's \(Display.massDelta(planned, in: unitSystem)) a week"
    }

    private func goalDetail(from trend: Double, to goal: Double) -> String {
        guard let weekly = series.weeklyChangeKG, abs(weekly) > 0.01 else {
            return "No measurable movement yet"
        }
        let weeks = (goal - trend) / weekly
        guard weeks > 0, let phrase = Display.duration(weeks: weeks) else {
            return "Moving away from it at this rate"
        }
        return "\(phrase) at the rate you are actually going"
    }

    /// The profile's weight is something the user chose; the trend is something
    /// measured. When they drift apart, the app offers rather than assumes.
    @ViewBuilder
    private var profileNudge: some View {
        if let profile,
           let trend = series.trendKG,
           let onAdoptWeight {
            // Shown whenever the two differ at all, rather than only past half
            // a kilo. The trend moves slowly by design — one new reading shifts
            // it a tenth — so a threshold big enough to be "worth mentioning"
            // meant the button was missing exactly when someone had just
            // weighed in and gone looking for it.
            let difference = trend - profile.metrics.weightKG

            Card {
                HStack(spacing: 10) {
                    // Both numbers and the action on one line. Spelled out in a
                    // sentence this took three lines to say what two figures and
                    // a button say here.
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Profile \(Display.mass(profile.metrics.weightKG, in: unitSystem))")
                            .font(.footnote)
                        Text("Trend \(Display.mass(trend, in: unitSystem))")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Senku.Palette.protein)
                    }

                    Spacer(minLength: 8)

                    if abs(difference) < 0.05 {
                        Text("In step")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Button {
                            onAdoptWeight(trend)
                        } label: {
                            StackedActionLabel("Update", symbol: "arrow.up.circle")
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.bordered)
                        .tint(Senku.Palette.protein)
                        .accessibilityLabel("Update profile weight to \(Display.mass(trend, in: unitSystem))")
                    }
                }
            }
        }
    }

    // MARK: - History

    /// A page of readings at a time, newest first.
    ///
    /// The chart is the history; this list is for finding and fixing the one
    /// you mistyped. Rendering years of mornings to scroll past would be a
    /// scroll, not a feature — so it grows only when asked.

    private var empty: some View {
        ContentUnavailableView {
            Label("No weigh-ins yet", systemImage: "scalemass")
        } description: {
            Text("Log one and Senku starts tracking the trend underneath the noise — and, in time, what your maintenance calories actually are.")
        } actions: {
            Button("Log a weigh-in") { isAdding = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func display(_ kilograms: Double) -> Double {
        unitSystem == .metric ? kilograms : Convert.pounds(fromKilograms: kilograms)
    }
}

/// Entering one reading.
private struct WeighInEditor: View {
    let unitSystem: UnitSystem
    let suggested: Double?
    let onSave: (WeighIn) -> Void
    let onCancel: () -> Void

    @State private var weight: Double?
    @State private var date = Date.now

    init(
        unitSystem: UnitSystem,
        suggested: Double?,
        onSave: @escaping (WeighIn) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.unitSystem = unitSystem
        self.suggested = suggested
        self.onSave = onSave
        self.onCancel = onCancel
        // Seeded with the last known weight: a weigh-in is nearly always a
        // small change from the previous one, and typing 78.4 from scratch
        // every morning is friction with no purpose.
        _weight = State(
            initialValue: suggested.map { unitSystem == .metric ? $0 : Convert.pounds(fromKilograms: $0) }
        )
    }

    private var weightKG: Double? {
        guard let weight else { return nil }
        return unitSystem == .metric ? weight : Convert.kilograms(fromPounds: weight)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Senku.Metrics.stackSpacing) {
                    Card("Weigh-in") {
                        SliderField(
                            label: "Weight",
                            value: $weight,
                            range: unitSystem == .metric ? 35...200 : 77...440,
                            step: unitSystem == .metric ? 0.1 : 0.2,
                            decimals: 1,
                            unit: unitSystem.massLabel,
                            isRequired: true,
                            identifier: "field.weighIn"
                        )

                        Divider()

                        DatePicker("When", selection: $date, in: ...Date.now)
                            .font(.subheadline)
                    }

                    Text("Weigh yourself at the same time of day — first thing, before eating — or the trend measures your breakfast.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .background(.background)
            .dismissableKeyboard()
            .navigationTitle("Log weight")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let weightKG, let entry = try? WeighIn(date: date, weightKG: weightKG) else { return }
                        onSave(entry)
                    }
                    .disabled(weightKG == nil)
                }
            }
        }
    }
}
#endif
