#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The workout tab: pick today's day, or carry on with the one you started.
///
/// Opened standing up, often with a bar waiting, so the first thing on it is
/// always the thing to tap: a live session if there is one, and otherwise the
/// list of days. Setup, history and coverage detail are all one level down —
/// they are worth having and are never what you came for.
public struct WorkoutView: View {
    @Bindable private var plans: TrainingPlanStore
    @Bindable private var workouts: WorkoutStore
    @Bindable private var records: RecordStore
    @Bindable private var cardioRecords: CardioRecordStore
    @Bindable private var library: ExerciseLibrary

    private let unitSystem: UnitSystem

    @State private var isSettingUp = false
    @State private var isShowingHistory = false
    @State private var finished: WorkoutSession?
    @State private var reviewing: WorkoutSession?

    public init(
        plans: TrainingPlanStore,
        workouts: WorkoutStore,
        records: RecordStore,
        cardioRecords: CardioRecordStore,
        library: ExerciseLibrary,
        unitSystem: UnitSystem
    ) {
        self.plans = plans
        self.workouts = workouts
        self.records = records
        self.cardioRecords = cardioRecords
        self.library = library
        self.unitSystem = unitSystem
    }

    public var body: some View {
        Group {
            if let live = workouts.live {
                WorkoutSessionView(
                    session: live,
                    workouts: workouts,
                    records: records,
                    cardioRecords: cardioRecords,
                    library: library,
                    unitSystem: unitSystem,
                    onFinish: { finished = $0 }
                )
            } else if plans.readyDays.isEmpty {
                emptyState
            } else {
                dayChooser
            }
        }
        .toolbar {
            if workouts.live == nil, plans.hasPlan {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingHistory = true
                    } label: {
                        Label("Logged workouts", systemImage: "clock.arrow.circlepath")
                    }
                    .disabled(workouts.history.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isSettingUp = true
                    } label: {
                        Label("Edit my week", systemImage: "slider.horizontal.3")
                    }
                }
            }
        }
        .navigationDestination(isPresented: $isSettingUp) {
            PlanSetupView(store: plans, library: library)
        }
        .navigationDestination(isPresented: $isShowingHistory) {
            WorkoutHistoryView(
                workouts: workouts,
                library: library,
                unitSystem: unitSystem
            )
        }
        .sheet(item: $reviewing) { session in
            NavigationStack {
                WorkoutSummaryView(
                    session: session,
                    library: library,
                    unitSystem: unitSystem
                )
            }
        }
        .sheet(item: $finished) { session in
            NavigationStack {
                WorkoutSummaryView(
                    session: session,
                    library: library,
                    unitSystem: unitSystem
                )
            }
        }
    }

    // MARK: - Nothing set up yet

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No workout days yet", systemImage: "figure.strengthtraining.traditional")
        } description: {
            Text(plans.hasPlan
                 ? "Your days have no exercises in them yet."
                 : "Set up the days you train and what you do on each. It takes a few minutes, once.")
        } actions: {
            Button(plans.hasPlan ? "Finish setting up" : "Set up my week") {
                isSettingUp = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Choosing today

    private var dayChooser: some View {
        let done = workouts.completedDays(in: plans.plan)
        let outstanding = plans.readyDays.filter { !done.contains($0.id) }

        return List {
            Section {
                ForEach(plans.readyDays) { day in
                    let isDone = done.contains(day.id)

                    Button {
                        // A day already trained this week opens as a record of
                        // what you did, not as a fresh session. The week is the
                        // unit the plan is written in, and starting Legs twice
                        // in one week is nearly always a mis-tap rather than a
                        // decision — so the second tap shows you the workout
                        // you are half-remembering instead of quietly opening
                        // an empty one over the top of it.
                        if isDone {
                            reviewing = workouts.lastSession(forDay: day.id)
                        } else {
                            workouts.start(day)
                        }
                    } label: {
                        dayCard(day, isDone: isDone)
                    }
                    // A grey ground for a day already trained. The tick and the
                    // faded glyphs say it too, but the row's own background is
                    // what reads at a glance, before anything on it is looked
                    // at — which is the whole question this screen answers.
                    .listRowBackground(rowBackground(isDone: isDone))
                }
            } header: {
                // What is left of the round, rather than a flat instruction.
                // "1 of 3 left" is the thing being asked when this screen is
                // opened, and the answer changes as the week goes on.
                if outstanding.isEmpty {
                    Text("Every day done this week")
                } else if done.isEmpty {
                    Text("What are you doing today?")
                } else {
                    Text("\(outstanding.count) of \(plans.readyDays.count) left this week")
                }
            }
        }
    }

    /// Grey for a day already trained, and the list's own card colour
    /// otherwise — which has to be named explicitly, because setting a row
    /// background at all replaces the default rather than tinting it.
    private func rowBackground(isDone: Bool) -> Color {
        if isDone { return Color.secondary.opacity(0.12) }
        #if os(iOS)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #else
        return Color.clear
        #endif
    }

    private func dayCard(_ day: SplitDay, isDone: Bool) -> some View {
        let exercises = day.exerciseIDs.compactMap { library.exercise($0) }
        let last = workouts.lastSession(forDay: day.id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(day.groups) { group in
                    GroupGlyph(group: group, size: 26)
                        // Faded rather than hidden: a finished day stays on the
                        // list and stays startable, because doing legs twice in
                        // a week is a decision the app has no business
                        // refusing.
                        .opacity(isDone ? 0.45 : 1)
                }
                Spacer()
                Image(systemName: isDone ? "eye" : "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Senku.Palette.surplus)
                }
                Text(day.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isDone ? Color.secondary : Color.primary)
            }

            HStack(spacing: 6) {
                if isDone {
                    Text("Done this week — tap to see it")
                } else {
                    Text("\(exercises.count) exercises")
                    if let last {
                        // Named relative — "3 days ago" is the form the question
                        // is asked in, never a date.
                        Text("·")
                        Text("last \(last.date.formatted(.relative(presentation: .named)))")
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Everything logged, newest first.
struct WorkoutHistoryView: View {
    @Bindable var workouts: WorkoutStore
    @Bindable var library: ExerciseLibrary
    let unitSystem: UnitSystem

    @State private var showing: WorkoutSession?

    var body: some View {
        List {
            ForEach(workouts.history) { session in
                Button {
                    showing = session
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.dayName)
                                .font(.headline)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(session.totalSets) sets · \(Display.mass(session.volumeKG, in: unitSystem, decimals: 0)) moved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    workouts.delete(workouts.history[index])
                }
            }
        }
        .senkuBottomBarInset()
        .navigationTitle("History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $showing) { session in
            NavigationStack {
                WorkoutSummaryView(
                    session: session,
                    library: library,
                    unitSystem: unitSystem
                )
            }
        }
    }
}
#endif
