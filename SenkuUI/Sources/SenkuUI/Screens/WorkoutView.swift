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
    @State private var isCalculatingPlates = false
    @State private var plates: PlateStore
    @State private var isShowingHistory = false
    @State private var finished: WorkoutSession?
    @State private var reviewing: WorkoutSession?
    /// The day opened out to show its exercises and the button that starts it.
    @State private var expanded: UUID?

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
        // The profile's unit is only the starting point; a choice made on the
        // calculator itself is about a particular gym and outranks it.
        _plates = State(initialValue: PlateStore(defaultUnit: unitSystem))
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
                    target: plans.plan.target,
                    onFinish: { finished = $0 }
                )
            } else if plans.readyDays.isEmpty {
                emptyState
            } else {
                dayChooser
            }
        }
        .toolbar {
            // Always there, live session or not: the bar is loaded before the
            // first set and again between every one of them.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCalculatingPlates = true
                } label: {
                    StackedActionLabel("Plates", symbol: "dumbbell.fill")
                }
            }

            if workouts.live == nil, plans.hasPlan {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingHistory = true
                    } label: {
                        StackedActionLabel("History", symbol: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Logged workouts")
                    .disabled(workouts.history.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isSettingUp = true
                    } label: {
                        StackedActionLabel("Week", symbol: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Edit my week")
                }
            }
        }
        .navigationDestination(isPresented: $isCalculatingPlates) {
            PlateCalculatorView(plates: plates)
        }
        .navigationDestination(isPresented: $isSettingUp) {
            PlanSetupView(store: plans, library: library)
        }
        .navigationDestination(isPresented: $isShowingHistory) {
            WorkoutHistoryView(
                workouts: workouts,
                library: library,
                records: records,
                plan: plans.plan,
                unitSystem: unitSystem
            )
        }
        .senkuPushed(isCalculatingPlates, isSettingUp, isShowingHistory)
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
                    unitSystem: unitSystem,
                    sendsToHealthOnDone: true
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

                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            // A day already trained this week opens as a record
                            // of what you did, not as a fresh session. The week
                            // is the unit the plan is written in, and starting
                            // Legs twice in one week is nearly always a mis-tap
                            // rather than a decision — so the second tap shows
                            // you the workout you are half-remembering instead
                            // of quietly opening an empty one over it.
                            //
                            // Any other day opens out first: what is in it, and
                            // Start. A tap that starts a session straight away was
                            // a session started by brushing the list.
                            if isDone {
                                reviewing = workouts.lastSession(forDay: day.id)
                            } else {
                                withAnimation(.snappy) {
                                    expanded = expanded == day.id ? nil : day.id
                                }
                            }
                        } label: {
                            dayCard(day, isDone: isDone, isExpanded: expanded == day.id)
                        }

                        if expanded == day.id, !isDone {
                            dayDetail(day)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    // Borderless, so the header and Start are two buttons rather
                    // than one row-sized one.
                    .buttonStyle(.borderless)
                    // A grey ground for a day already trained. The tick and the
                    // faded glyphs say it too, but the row's own background is
                    // what reads at a glance, before anything on it is looked
                    // at — which is the whole question this screen answers.
                    .listRowBackground(rowBackground(isDone: isDone))
                }
            }

            // Where the week stands, after the days rather than over them:
            // a track with a segment per day, lit as each one is trained.
            Section {
                weekTrack(days: plans.readyDays, done: done)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
        }
    }

    /// The week as steps: a circle per day joined by a line, ticked from the
    /// left as days are trained in whatever order — two done ticks 1 and 2 —
    /// the next ringed, the rest waiting, and a line saying how far through.
    private func weekTrack(days: [SplitDay], done: Set<UUID>) -> some View {
        let count = days.filter { done.contains($0.id) }.count
        let total = days.count
        let tint = RootView.Tab.workout.tint
        // Counts down from the whole week, the same line before a day is
        // trained as after.
        let message = count == total ? "Week cleared." : "\(total - count) to go this week"

        return VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(Array(days.indices), id: \.self) { index in
                    if index > 0 {
                        Rectangle()
                            .fill(tint.opacity(0.7))
                            .frame(height: 2)
                    }
                    stepNode(index + 1, isDone: index < count, isNext: index == count, tint: tint)
                }
            }
            // Room for the ring round the next day, which is drawn outside
            // its circle so the line runs right up to every circle.
            .padding(6)

            HStack(spacing: 6) {
                if count == total, total > 0 {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(tint)
                }
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(count == total ? Color.primary : Color.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of \(total) days done this week")
    }

    private func stepNode(_ number: Int, isDone: Bool, isNext: Bool, tint: Color) -> some View {
        let size: CGFloat = 34
        return ZStack {
            if isDone {
                Circle().fill(tint)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
            } else if isNext {
                Circle().fill(tint)
                Circle()
                    .strokeBorder(tint, lineWidth: 2)
                    .padding(-5)
                Text("\(number)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Circle().fill(.background)
                Circle().strokeBorder(tint, lineWidth: 2)
                Text("\(number)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
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

    /// An opened day: its muscles large on the left, and Start on the right.
    private func dayDetail(_ day: SplitDay) -> some View {
        HStack(spacing: 12) {
            // From the left, under the day's name; scrolling only when a day
            // has more muscles than the row has room for.
            ViewThatFits(in: .horizontal) {
                bigGroups(day).frame(maxWidth: .infinity, alignment: .leading)
                ScrollView(.horizontal, showsIndicators: false) { bigGroups(day) }
                    .scrollBounceBehavior(.basedOnSize)
            }

            Button {
                expanded = nil
                workouts.start(day, target: plans.plan.target)
            } label: {
                Text("Start")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .background(Capsule().fill(Senku.Palette.surplus))
            }
            .accessibilityLabel("Start \(day.name)")
        }
        .padding(.bottom, 4)
    }

    private func bigGroups(_ day: SplitDay) -> some View {
        HStack(spacing: 18) {
            ForEach(Array(Set(day.groups)).sorted { $0.rawValue < $1.rawValue }) { group in
                VStack(spacing: 4) {
                    GroupGlyph(group: group, size: 48)
                    Text(group.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func dayCard(_ day: SplitDay, isDone: Bool, isExpanded: Bool = false) -> some View {
        let exercises = day.exerciseIDs.compactMap { library.exercise($0) }
        let last = workouts.lastSession(forDay: day.id)

        // Laid out like the Week page: name and summary on the left, the
        // muscles in a bordered box and the way in on the right, centred on
        // the row.
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Senku.Palette.surplus)
                    }
                    Text(day.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isDone ? Color.secondary : Color.primary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if isDone {
                        Text("Done this week. Tap to see it")
                    } else {
                        Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")")
                        if let last {
                            // Named relative — "3 days ago" is the form the
                            // question is asked in, never a date. On its own:
                            // "last" in front read "last last week" and
                            // "last yesterday".
                            Text("·")
                            Text(last.date.formatted(.relative(presentation: .named)))
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            // Opened, the muscles are drawn large underneath instead.
            if !day.groups.isEmpty, !isExpanded {
                MuscleGroupBox(groups: day.groups, size: 24)
                    // Faded rather than hidden: a finished day stays on the
                    // list and stays startable, because doing legs twice in a
                    // week is a decision the app has no business refusing.
                    .opacity(isDone ? 0.45 : 1)
            }

            Image(systemName: isDone ? "eye" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 22, alignment: .trailing)
        }
        .padding(.vertical, 4)
        // The whole row, gaps included: a borderless button is otherwise
        // only hittable on what it draws.
        .contentShape(Rectangle())
        // Primary underneath, so the grey lines are grey: inside a button they
        // otherwise come out in the button's tint, which reads as orange.
        .foregroundStyle(Color.primary)
    }
}

/// Everything logged, newest first, in training weeks.
///
/// The week you are in lists its workouts one by one while it is being
/// trained; every other week — and this one, once every day of the plan is
/// done — is a card. A card says what the week added up to, and opens on the
/// whole of it: the numbers against the week before, which days of the plan
/// were done, what the body got, and the workouts themselves.
struct WorkoutHistoryView: View {
    @Bindable var workouts: WorkoutStore
    @Bindable var library: ExerciseLibrary
    @Bindable var records: RecordStore
    let plan: TrainingPlan
    let unitSystem: UnitSystem

    @State private var showing: WorkoutSession?
    /// The one week open. Opening another closes it.
    @State private var expanded: Date?

    var body: some View {
        let layout = WorkoutHistoryLayout.make(history: workouts.history, plan: plan)

        List {
            if !layout.thisWeek.isEmpty {
                Section("This week") {
                    sessionRows(layout.thisWeek)
                }
            }

            // A card of its own for each week, close together: the wide gap
            // is the one between this week's workouts and the weeks.
            ForEach(Array(layout.weeks.enumerated()), id: \.element.id) { index, week in
                let previous = layout.weeks.indices.contains(index + 1) ? layout.weeks[index + 1] : nil
                let isOpen = expanded == week.id

                Section {
                    Button {
                        withAnimation(.snappy) {
                            expanded = isOpen ? nil : week.id
                        }
                    } label: {
                        weekCard(week, isOpen: isOpen)
                    }

                    if isOpen {
                        WeekAnalysis(
                            week: week,
                            previous: previous,
                            plan: plan,
                            records: records,
                            library: library,
                            unitSystem: unitSystem
                        )
                        sessionRows(week.sessions)
                    }
                } header: {
                    // Labels where the list changes: this week, once it is a
                    // finished card of its own, and the first week before it.
                    if week.interval.contains(.now) {
                        Text("This week")
                    } else if index == 0 || layout.weeks[index - 1].interval.contains(.now) {
                        Text("Previous weeks")
                    }
                }
                #if os(iOS)
                .listSectionSpacing(8)
                #endif
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

    private func sessionRows(_ sessions: [WorkoutSession]) -> some View {
        ForEach(sessions) { session in
            Button {
                showing = session
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.dayName)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Text(session.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    let prs = session.recordsSet(in: records.records)
                    Text("\(session.totalSets) sets" + (prs > 0 ? " · \(prs) \(prs == 1 ? "PR" : "PRs")" : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.primary)
            }
        }
        .onDelete { offsets in
            offsets.map { sessions[$0] }.forEach(workouts.delete)
        }
    }

    private func weekCard(_ week: WorkoutWeek, isOpen: Bool) -> some View {
        let days = week.trainingDays()
        let exercises = week.performedExerciseIDs.count
        let prs = week.recordsSet(in: records.records)
        let performed = week.performedExerciseIDs.compactMap { library.exercise($0) }
        let covered = BodyMapPart.trainedShare(of: BodyMapPart.coverage(of: performed))

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.title(of: week))
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                // In columns, so they line up from one week to the next
                // whatever the counts.
                HStack(spacing: 6) {
                    column("\(days) \(days == 1 ? "day" : "days")", widest: "0 days")
                    Text("·")
                    column("\(exercises) \(exercises == 1 ? "exercise" : "exercises")", widest: "00 exercises")
                    if prs > 0 {
                        Text("·")
                        column("\(prs) \(prs == 1 ? "PR" : "PRs")", widest: "00 PRs")
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Spacer()

            // How much of the body the week reached: the green on its map.
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(Int((covered * 100).rounded()))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Senku.Palette.surplus)
                Text("MUSCLES")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isOpen ? 180 : 0))
        }
        .padding(.vertical, 4)
    }

    /// A figure as wide as the widest it could be, so columns hold still.
    private func column(_ text: String, widest: String) -> some View {
        ZStack(alignment: .leading) {
            Text(widest).hidden()
            Text(text)
        }
    }

    /// The week's dates, month first at both ends: "Oct 6 – Oct 12". Put
    /// together by hand, because a date format would put the day first
    /// wherever the region does.
    static func title(of week: WorkoutWeek) -> String {
        func monthDay(_ date: Date) -> String {
            "\(date.formatted(.dateTime.month(.abbreviated))) \(date.formatted(.dateTime.day()))"
        }
        return "\(monthDay(week.interval.start)) – \(monthDay(week.interval.end.addingTimeInterval(-1)))"
    }
}

/// The whole of a training week, under its card.
private struct WeekAnalysis: View {
    let week: WorkoutWeek
    let previous: WorkoutWeek?
    let plan: TrainingPlan
    @Bindable var records: RecordStore
    @Bindable var library: ExerciseLibrary
    let unitSystem: UnitSystem

    private var newRecords: Int { week.recordsSet(in: records.records) }

    /// Against the week before, only when it really is the week before.
    private var volumeChange: Double? {
        guard let previous, previous.volumeKG > 0,
              abs(week.interval.start.timeIntervalSince(previous.interval.start) - 7 * 86_400) < 2 * 3600
        else { return nil }
        return (week.volumeKG - previous.volumeKG) / previous.volumeKG
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            stats
            splits
            bodyMap
        }
        .padding(.vertical, 6)
    }

    // MARK: - Numbers

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 10) {
            stat("Exercises", "\(week.performedExerciseIDs.count)")
            stat("Sets", "\(week.totalSets)")
            stat("Moved", Display.mass(week.volumeKG, in: unitSystem, decimals: 0), change: volumeChange)
            if week.trainedSeconds > 0 {
                stat("Time", Display.clock(week.trainedSeconds))
            }
            if week.cardioSeconds > 0 {
                stat("Cardio", "\(Int((week.cardioSeconds / 60).rounded())) min")
            }
            if newRecords > 0 {
                stat("PRs", "\(newRecords)")
            }
        }
    }

    private func stat(_ label: String, _ value: String, change: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.tertiary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                if let change, abs(change) >= 0.005 {
                    Text("\(change > 0 ? "+" : "")\(Int((change * 100).rounded()))%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(change > 0 ? Senku.Palette.surplus : Senku.Palette.warning)
                }
            }
        }
    }

    // MARK: - The plan

    /// Each day of the plan, done or not.
    @ViewBuilder
    private var splits: some View {
        let days = plan.days.filter { !$0.isEmpty }
        if !days.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(days) { day in
                    let done = week.dayIDs.contains(day.id)
                    HStack(spacing: 8) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? Senku.Palette.surplus : Color.secondary)
                        Text(day.name)
                            .font(.subheadline)
                            .foregroundStyle(done ? Color.primary : Color.secondary)
                    }
                }
            }
        }
    }

    // MARK: - The body

    /// What the week trained, on the body: green for trained, red for what the
    /// week's own groups asked for and did not get.
    private var bodyMap: some View {
        let performed = week.performedExerciseIDs.compactMap { library.exercise($0) }
        let coverage = BodyMapPart.coverage(of: performed)
        let planned = Set(week.groups)

        return VStack(spacing: 8) {
            BodyHighlight { part in
                switch part.state(coverage: coverage, plannedGroups: planned) {
                case .trained: BodyHighlight.trained
                case .missed: BodyHighlight.missed
                case nil: nil
                }
            }
            .frame(height: 200)

            HStack(spacing: 14) {
                BodyHighlightKey(color: BodyHighlight.trained, label: "Trained")
                BodyHighlightKey(color: BodyHighlight.missed, label: "Not trained")
            }
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
