#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The checklist: the day you chose, one row per exercise, sets logged into it.
///
/// This is the screen held in one hand between sets, so it is a list of big
/// rows and nothing else. Every row says the same three things in the same
/// places — what it is, what you did last time, what you have done today — and
/// tapping one opens the only thing there is to do with it.
struct WorkoutSessionView: View {
    let session: WorkoutSession

    @Bindable var workouts: WorkoutStore
    @Bindable var records: RecordStore
    @Bindable var cardioRecords: CardioRecordStore
    @Bindable var library: ExerciseLibrary
    let unitSystem: UnitSystem
    let target: RepTarget
    let onFinish: (WorkoutSession) -> Void

    @State private var logging: LoggingTarget?
    /// The exercise whose info sheet is open.
    @State private var info: Exercise?
    @State private var isAdding = false
    @State private var isConfirmingFinish = false
    @State private var isConfirmingDiscard = false

    private var live: WorkoutSession { workouts.live ?? session }

    var body: some View {
        List {
            progressSection
            checklistSection
            finishSection
        }
        .navigationTitle(live.dayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $info) { exercise in
            ExerciseInfoSheet(
                exercise: exercise,
                library: library,
                refusal: nil,
                onDelete: nil,
                onClose: { info = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(ExercisePicker.solidSheet)
        }
        .sheet(item: $logging) { target in
            NavigationStack {
                if library.exercise(target.id)?.isCardio == true {
                    CardioLogger(
                        exerciseID: target.id,
                        workouts: workouts,
                        cardioRecords: cardioRecords,
                        library: library,
                        unitSystem: unitSystem
                    )
                } else {
                    SetLogger(
                        exerciseID: target.id,
                        workouts: workouts,
                        records: records,
                        library: library,
                        unitSystem: unitSystem,
                        target: live.entry(target.id)?.target ?? self.target
                    )
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                ExercisePicker(
                    library: library,
                    hidden: Set(live.entries.map(\.exerciseID))
                ) { exercise in
                    workouts.addExercise(exercise.id, target: target)
                    isAdding = false
                }
                .navigationTitle("Add to Today")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { isAdding = false }
                    }
                }
            }
        }
        // An alert, like the app's other "are you sure" questions — a dialog
        // sliding up from the button reads as a menu of choices.
        .alert(
            "Finish this workout?",
            isPresented: $isConfirmingFinish
        ) {
            Button("Finish") {
                if let done = workouts.finish() { onFinish(done) }
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text(live.outstandingCount > 0
                 ? "\(live.outstandingCount) exercises have nothing logged. They will be recorded as not done."
                 : "Everything is logged.")
        }
        // An alert rather than a sheet of choices. A confirmation dialog slides
        // up from the button that summoned it and reads as a menu — fine for
        // "which of these", wrong for "are you sure", where the point is to
        // stop and be read. This one destroys an hour's logging.
        .alert(
            "Throw this workout away?",
            isPresented: $isConfirmingDiscard
        ) {
            Button("Discard", role: .destructive) { workouts.discardLive() }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Every set logged today is deleted. Personal records made are kept.")
        }
    }

    // MARK: - Sections

    private var progressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                // How long you have been at it, at the head of the card: the
                // one figure on this screen that changes while you rest.
                SessionClock(since: live.date)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)

                HStack {
                    ForEach(live.groups) { group in
                        GroupGlyph(group: group, size: 24)
                    }
                    Spacer()
                    Text("\(live.completedCount)/\(live.entries.count)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }

                ProgressView(
                    value: Double(live.completedCount),
                    total: Double(max(1, live.entries.count))
                )
                .tint(Senku.Palette.protein)

                Text(headline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    /// The checklist, split by muscle.
    ///
    /// A push day is chest work and triceps work, and doing them as one flat
    /// list makes you read every row to find where the chest ends. Each
    /// exercise is filed under the group it is *for* — its catalogue group when
    /// the day trains that, and otherwise the first of the day's groups it
    /// actually contributes to, which is what puts a close-grip press in the
    /// triceps block of a day that has no chest in it.
    /// "12 sets · 640 kg moved · 22 min cardio" — only the parts that happened.
    private var headline: String {
        var parts: [String] = []
        if live.totalSets > 0 {
            parts.append("\(live.totalSets) sets")
            parts.append("\(Display.mass(live.volumeKG, in: unitSystem, decimals: 0)) moved")
        }
        if live.cardioSeconds > 0 {
            parts.append("\(Int((live.cardioSeconds / 60).rounded())) min cardio")
        }
        return parts.isEmpty ? "Nothing logged yet" : parts.joined(separator: " · ")
    }

    private var checklistSection: some View {
        ForEach(blocks, id: \.id) { block in
            Section {
                ForEach(block.entries) { entry in
                    Button {
                        logging = LoggingTarget(id: entry.exerciseID)
                    } label: {
                        row(entry)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            workouts.setSkipped(!entry.isSkipped, for: entry.exerciseID)
                        } label: {
                            Label(
                                entry.isSkipped ? "Unskip" : "Skip",
                                systemImage: entry.isSkipped ? "arrow.uturn.backward" : "forward.end"
                            )
                        }
                        .tint(Senku.Palette.caution)
                    }
                    .swipeActions(edge: .trailing) {
                        if !entry.hasAnyWork {
                            Button(role: .destructive) {
                                workouts.removeExercise(entry.exerciseID)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }

                if block.isLast {
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add an exercise", systemImage: "plus")
                    }
                }
            } header: {
                if let group = block.group {
                    HStack(spacing: 6) {
                        GroupGlyph(group: group, size: 16)
                        Text(group.title)
                    }
                } else {
                    Text("Also today")
                }
            }
        }
    }

    /// One muscle's worth of the checklist.
    private struct Block {
        let group: WorkoutGroup?
        let entries: [WorkoutEntry]
        var isLast = false

        var id: String { group?.rawValue ?? "senku.block.other" }
    }

    private var blocks: [Block] {
        var byGroup: [String: [WorkoutEntry]] = [:]
        var loose: [WorkoutEntry] = []

        for entry in live.entries {
            if let group = group(for: entry) {
                byGroup[group.rawValue, default: []].append(entry)
            } else {
                loose.append(entry)
            }
        }

        // The day's own order, so the blocks read in the order the day names
        // its muscles rather than in whatever order the exercises were added.
        var blocks = live.groups
            .compactMap { group -> Block? in
                guard let entries = byGroup[group.rawValue] else { return nil }
                return Block(group: group, entries: entries)
            }

        if !loose.isEmpty {
            blocks.append(Block(group: nil, entries: loose))
        }
        if !blocks.isEmpty {
            blocks[blocks.count - 1].isLast = true
        }
        return blocks
    }

    private func group(for entry: WorkoutEntry) -> WorkoutGroup? {
        guard let exercise = library.exercise(entry.exerciseID) else { return nil }

        if live.groups.contains(exercise.workoutGroup) {
            return exercise.workoutGroup
        }
        return live.groups.first { group in
            !MuscleCoverage.contributors(
                among: [exercise],
                to: group,
                in: library.catalogue
            ).isEmpty
        }
    }

    private func row(_ entry: WorkoutEntry) -> some View {
        HStack(spacing: 12) {
            // The tick is the whole point of a checklist: it has to be readable
            // at arm's length, in a mirror, mid-set — and it is a control, not
            // an indicator. Tapping it says "done" without opening anything,
            // for the sets you did and did not write down.
            Button {
                Feedback.control()
                workouts.setMarkedDone(!entry.isMarkedDone, for: entry.exerciseID)
            } label: {
                Image(systemName: mark(for: entry))
                    .font(.title2)
                    .foregroundStyle(markTint(for: entry))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.isMarkedDone ? "Mark not done" : "Mark done")
            // Usable at any point: two sets and stopping is a decision, and the
            // tick records it without inventing a third set. Only a cardio
            // entry has nothing to say here, since logging it is the tick.
            .disabled(entry.cardio != nil)

            VStack(alignment: .leading, spacing: 2) {
                // `Color.primary`, not `.primary`. The bare form is a
                // hierarchical style, and a hierarchical style resolves against
                // whatever colour it finds itself in — which inside a tinted
                // button is the tint. That is why these rows were green on a
                // green-accented tab despite being told to be primary: they
                // were obeying, and primary *was* green.
                HStack(spacing: 6) {
                    Text(library.name(of: entry.exerciseID))
                        .font(.body.weight(.medium))
                        .foregroundStyle(entry.isSkipped ? Color.secondary : Color.primary)
                        .strikethrough(entry.isSkipped)

                    if stepUp(for: entry) != nil {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(Senku.Palette.surplus)
                            .accessibilityLabel("Ready to go heavier")
                    }
                }

                Text(detail(for: entry))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            if entry.cardio == nil, !entry.sets.isEmpty {
                Text(entry.setProgress)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(Color.secondary)
            }

            // What the exercise is, without leaving the session — the same
            // sheet as the exercise list's. Its own button, so tapping it
            // does not open the set logger the rest of the row opens.
            if let exercise = library.exercise(entry.exerciseID) {
                Button {
                    info = exercise
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(Senku.Palette.protein)
                        .frame(width: 30, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About \(exercise.name)")
            }
        }
        .padding(.vertical, 2)
        // Tappable across its width, not only on the text.
        .contentShape(Rectangle())
    }

    private func mark(for entry: WorkoutEntry) -> String {
        if entry.isDone { return "checkmark.circle.fill" }
        if entry.isSkipped { return "minus.circle" }
        // Started but not finished: a row with two of three sets should not
        // look like one nobody has touched.
        if entry.hasAnyWork { return "circle.lefthalf.filled" }
        return "circle"
    }

    private func markTint(for entry: WorkoutEntry) -> Color {
        if entry.isDone { return Senku.Palette.surplus }
        if entry.hasAnyWork { return Senku.Palette.caution }
        return Color.secondary
    }

    /// What you did today, or — before you have done anything — what you did
    /// last time, which is very nearly always what you are about to do.
    private func detail(for entry: WorkoutEntry) -> String {
        if entry.isMarkedDone, entry.sets.isEmpty, entry.cardio == nil {
            return "Done — nothing logged"
        }
        if let cardio = entry.cardio {
            return Display.cardio(cardio, for: library.exercise(entry.exerciseID), in: unitSystem)
        }
        if !entry.sets.isEmpty {
            return entry.sets
                .map { Display.set(weightKG: $0.weightKG, reps: $0.reps, seconds: $0.seconds, in: unitSystem) }
                .joined(separator: "  ")
        }
        if entry.isSkipped { return "Skipped" }

        guard let (session, last) = workouts.lastEntry(forExercise: entry.exerciseID),
              let best = last.longestHold ?? last.heaviestSet
        else { return "Nothing logged before" }

        let figure = Display.set(
            weightKG: best.weightKG,
            reps: best.reps,
            seconds: best.seconds,
            in: unitSystem
        )
        let when = "Last: \(figure), \(session.date.formatted(.relative(presentation: .named)))"
        guard let stepUp = stepUp(for: entry) else { return when }
        return "\(when) · \(stepUp.hint(in: unitSystem))"
    }

    /// Only before today's first set: once you are lifting, the row shows
    /// what you are doing, and the logger has already offered the weight.
    private func stepUp(for entry: WorkoutEntry) -> StepUp? {
        guard entry.sets.isEmpty, !entry.isSkipped, !entry.isMarkedDone, entry.cardio == nil
        else { return nil }
        return StepUp.earned(for: entry.exerciseID, in: workouts, target: entry.target ?? target, unitSystem: unitSystem)
    }

    /// Finish and discard, side by side.
    ///
    /// Sharing a line is right because they are the two ways this screen ends,
    /// and a stack of two full-width buttons reads as a list of actions to work
    /// through. Finish takes the width and the colour; discard is a quiet
    /// bordered button, which is the weighting the two deserve.
    private var finishSection: some View {
        Section {
            HStack(spacing: 10) {
                Button {
                    isConfirmingFinish = true
                } label: {
                    Label("Finish", systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Senku.Palette.protein)
                .disabled(!live.hasAnything)

                Button(role: .destructive) {
                    isConfirmingDiscard = true
                } label: {
                    Text("Discard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                // The destructive role alone leaves it in the tab's accent,
                // which on this tab is green — the one colour a discard button
                // must not be.
                .tint(Senku.Palette.warning)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }
}

/// Time since the session began — since the split day was chosen — as
/// hours, minutes and seconds.
///
/// Minutes and seconds for the first hour, hours added from then on. Digits
/// of equal width, so the seconds tick without the rest shuffling sideways.
///
/// Stops at three hours, in red. Past that it is almost certainly not a
/// session any more but one nobody finished — the same mark the Apple Health
/// card questions a duration at — and a clock climbing on into the evening
/// would only be counting the time since you went home.
private struct SessionClock: View {
    let since: Date

    private static let limit = WorkoutEnergy.longest

    var body: some View {
        TimelineView(.periodic(from: since, by: 1)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(since))
            let isOver = elapsed >= Self.limit
            let shown = min(elapsed, Self.limit)

            HStack(spacing: 8) {
                Image(systemName: "stopwatch")
                    .font(.title3)
                    .foregroundStyle(isOver ? Senku.Palette.warning : .secondary)
                Text(Duration.seconds(shown.rounded(.down)).formatted(.time(
                    pattern: shown >= 3600 ? .hourMinuteSecond : .minuteSecond
                )))
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isOver ? Senku.Palette.warning : .primary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isOver
                ? "At the gym for over 3 hours"
                : "At the gym for \(Duration.seconds(elapsed).formatted(.units(allowed: [.hours, .minutes], width: .wide)))")
        }
    }
}

/// Logging sets for one exercise.
///
/// Opens on the weight and reps you used last time. That is not a convenience —
/// it is the difference between logging a session and not bothering: the
/// overwhelmingly common case is the same weight as last time, and the app
/// already knows it.
private struct SetLogger: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseID: String
    @Bindable var workouts: WorkoutStore
    @Bindable var records: RecordStore
    @Bindable var library: ExerciseLibrary
    let unitSystem: UnitSystem
    let target: RepTarget

    @State private var weight: Double = 0
    @State private var reps: Int = 8
    @State private var seconds: TimeInterval = 60
    @State private var newRecord: PersonalRecord?
    @State private var hasSeeded = false

    private var entry: WorkoutEntry? { workouts.live?.entry(exerciseID) }

    private var exercise: Exercise? { library.exercise(exerciseID) }

    private var isBodyweight: Bool { exercise?.equipment == .bodyweight }
    private var isTimed: Bool { exercise?.isTimed == true }

    var body: some View {
        Form {
            inputSection

            if let entry, !entry.sets.isEmpty {
                Section("Today") {
                    ForEach(entry.sets) { set in
                        HStack {
                            Text(Display.set(
                                weightKG: set.weightKG,
                                reps: set.reps,
                                seconds: set.seconds,
                                in: unitSystem
                            ))
                                .monospacedDigit()
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Text(set.completedAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            workouts.removeSet(entry.sets[index].id, from: exerciseID, records: records)
                        }
                    }
                }
            }

            if let standing = records.book.records(for: exerciseID).best, newRecord == nil {
                Section {
                    LabeledContent("Your record") {
                        Text(Display.set(
                            weightKG: standing.weightKG,
                            reps: standing.reps,
                            seconds: standing.seconds,
                            in: unitSystem
                        ))
                            .monospacedDigit()
                    }
                } footer: {
                    Text("Beat it here and the PR page updates itself.")
                }
            }

            if let newRecord {
                Section {
                    Label(
                        "New record: " + Display.set(
                            weightKG: newRecord.weightKG,
                            reps: newRecord.reps,
                            seconds: newRecord.seconds,
                            in: unitSystem
                        ),
                        systemImage: "trophy.fill"
                    )
                    .foregroundStyle(Senku.Palette.surplus)
                }
            }
        }
        .dismissableKeyboard()
        .navigationTitle(library.name(of: exerciseID))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            guard !hasSeeded else { return }
            hasSeeded = true
            seed()
        }
    }

    private var inputSection: some View {
        Section {
            if !isBodyweight {
                LabeledContent("Weight") {
                    HStack {
                        weightStepButton(-1)
                        TextField(
                            "Weight",
                            value: $weight,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        // Sized for three digits and a half — "142.5" — so the
                        // minus sits beside the number rather than across an
                        // empty field from it.
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                        .frame(width: 60)
                        Text(unitSystem.massLabel)
                            .foregroundStyle(.secondary)
                        weightStepButton(1)
                            .padding(.leading, 4)
                    }
                }
            }

            if isTimed {
                // Five-second steps: a plank is judged in fives, and a stepper
                // that counted single seconds would need twelve taps to reach
                // the minute everyone actually holds.
                Stepper(value: $seconds, in: 5...600, step: 5) {
                    LabeledContent("Hold", value: Display.hold(seconds))
                }
            } else {
                Stepper(value: $reps, in: 1...100) {
                    LabeledContent("Reps", value: "\(reps)")
                }
            }

            Button {
                addSet()
            } label: {
                Label("Log set", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Senku.Palette.protein)
        } footer: {
            if let stepUp, entry?.sets.isEmpty ?? true {
                Label(stepUp.explanation(target: target, in: unitSystem), systemImage: "arrow.up.circle.fill")
            }
        }
    }

    /// One plate pair either way — 2.5 kg or 5 lb — for the change that is
    /// nearly always one step, with the field still there for a bigger jump.
    /// Snaps to the step, so a typed 41 goes to 42.5 or 40 rather than 43.5.
    private func weightStepButton(_ direction: Double) -> some View {
        let step = unitSystem == .metric ? 2.5 : 5
        return Button {
            Feedback.control()
            let snapped = direction > 0
                ? (weight / step + 0.001).rounded(.down) * step + step
                : (weight / step - 0.001).rounded(.up) * step - step
            weight = max(0, snapped)
        } label: {
            Image(systemName: direction > 0 ? "plus.circle.fill" : "minus.circle.fill")
                .font(.title2)
                .foregroundStyle(Senku.Palette.protein)
        }
        .buttonStyle(.borderless)
        .disabled(direction < 0 && weight <= 0)
        .accessibilityLabel(direction > 0 ? "Increase weight" : "Decrease weight")
    }

    private var stepUp: StepUp? {
        StepUp.earned(for: exerciseID, in: workouts, target: target, unitSystem: unitSystem)
    }

    /// What to open on.
    ///
    /// In order: today's last set, then the personal record, then the last
    /// session. The record comes before the session history deliberately — an
    /// exercise already on the PR page has a number you have declared as the
    /// one that counts for it, and that is the figure to be working against
    /// when you step up to the bar. The traffic runs both ways: a set logged
    /// here that beats it updates the PR page in the same motion, so the two
    /// screens can never drift apart.
    private func seed() {
        if let last = entry?.sets.last {
            weight = converted(last.weightKG)
            reps = max(1, last.reps)
            if let held = last.seconds { seconds = held }
        } else if let stepUp {
            // Earned last time, so the next weight up is what to open on —
            // ahead of the record, which is a figure already beaten.
            weight = converted(stepUp.toKG)
            // Back to the bottom of the range at the new weight; a bodyweight
            // movement goes one past the top instead.
            reps = stepUp.isBodyweight ? target.topReps + 1 : target.reps
        } else if let record = records.book.records(for: exerciseID).best {
            weight = converted(record.weightKG)
            reps = max(1, record.reps)
            if let held = record.seconds { seconds = held }
        } else if let (_, previous) = workouts.lastEntry(forExercise: exerciseID),
                  let best = isTimed ? previous.longestHold : previous.heaviestSet {
            weight = converted(best.weightKG)
            reps = max(1, best.reps)
            if let held = best.seconds { seconds = held }
        }
    }

    private func converted(_ kilograms: Double) -> Double {
        unitSystem == .metric ? kilograms : Convert.pounds(fromKilograms: kilograms)
    }

    private func addSet() {
        let kilograms = unitSystem == .metric ? weight : Convert.kilograms(fromPounds: weight)
        guard let set = try? LoggedSet(
            weightKG: max(0, kilograms),
            reps: isTimed ? 0 : reps,
            seconds: isTimed ? seconds : nil
        ) else { return }

        Feedback.control()
        newRecord = workouts.log(set, for: exerciseID, records: records)
        #if os(iOS)
        // The set is done, so the rest begins: the Rest tab's own timer, at
        // the length set in Settings, counting on the lock screen while you
        // stay here. Logging the next set starts it again from that set.
        let restAfterSet = RestAfterSet.load()
        if restAfterSet.isOn {
            RestTimerStore.start(seconds: restAfterSet.seconds)
        }
        #endif
    }
}

/// What a finished workout came to.
struct WorkoutSummaryView: View {
    private func summary(for entry: WorkoutEntry) -> String {
        if let cardio = entry.cardio {
            return Display.cardio(cardio, for: library.exercise(entry.exerciseID), in: unitSystem)
        }
        if !entry.sets.isEmpty {
            return entry.sets
                .map { Display.set(weightKG: $0.weightKG, reps: $0.reps, seconds: $0.seconds, in: unitSystem) }
                .joined(separator: "  ")
        }
        // A hand-ticked exercise, in the summary and in the report: said as
        // what it is, rather than dressed up as sets that were never recorded.
        if entry.isMarkedDone { return "Done — nothing logged" }
        return entry.isSkipped ? "Skipped" : "Not done"
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.senkuBodyWeightKG) private var weightKG

    let session: WorkoutSession
    @Bindable var library: ExerciseLibrary
    let unitSystem: UnitSystem

    #if os(iOS)
    /// What Done will send to Apple Health — only on the summary that follows
    /// finishing, with Workouts switched on and the session not already sent.
    /// Reopening an old session from history sends nothing: looking at it is
    /// not a decision to put it in Health.
    @State private var healthDraft: HealthWorkoutDraft?
    #endif

    init(
        session: WorkoutSession,
        library: ExerciseLibrary,
        unitSystem: UnitSystem,
        sendsToHealthOnDone: Bool = false
    ) {
        self.session = session
        self.library = library
        self.unitSystem = unitSystem
        #if os(iOS)
        let health = HealthSync.shared
        if sendsToHealthOnDone, health.settings.isOn(.workouts), !health.hasWritten(session),
           let window = WorkoutEnergy.window(for: session) {
            _healthDraft = State(initialValue: HealthWorkoutDraft(session: session, window: window))
        }
        #endif
    }

    private var performed: [Exercise] {
        session.performedExerciseIDs.compactMap { library.exercise($0) }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Sets", value: "\(session.totalSets)")
                LabeledContent("Moved", value: Display.mass(session.volumeKG, in: unitSystem, decimals: 0))
                if let duration = session.duration, duration > 60 {
                    LabeledContent("Took", value: Display.clock(duration))
                }
            } header: {
                Text(session.date.formatted(date: .complete, time: .omitted))
            }

            #if os(iOS)
            if let healthDraft {
                HealthWorkoutSection(draft: healthDraft, unitSystem: unitSystem)
            }
            #endif

            Section {
                // Scored on what was performed, not what was planned — a
                // skipped pulldown is back you did not train, and a summary
                // that said otherwise would be flattering you with intentions.
                ForEach(session.groups) { group in
                    let coverage = MuscleCoverage.of(performed, for: group, in: library.catalogue)
                    HStack(spacing: 10) {
                        GroupGlyph(group: group, size: 22)
                        Text(group.title)
                        Spacer()
                        Text("\(coverage.percentage)%")
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(group.tint)
                    }
                }

                // The same, on the body: green for what was trained, red for
                // what the day's groups asked for and did not get.
                let regionCoverage = BodyMapPart.coverage(of: performed)
                let planned = Set(session.groups)
                VStack(spacing: 8) {
                    BodyHighlight { part in
                        switch part.state(coverage: regionCoverage, plannedGroups: planned) {
                        case .trained: BodyHighlight.trained
                        case .missed: BodyHighlight.missed
                        case nil: nil
                        }
                    }
                    .frame(height: 230)

                    HStack(spacing: 14) {
                        BodyHighlightKey(color: BodyHighlight.trained, label: "Trained")
                        BodyHighlightKey(color: BodyHighlight.missed, label: "Not trained")
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("What you trained")
            }

            Section("Exercises") {
                ForEach(session.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(library.name(of: entry.exerciseID))
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.primary)
                        Text(summary(for: entry))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(session.dayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                // Done is the confirmation: it sends what the Apple Health
                // card shows. Swiping the sheet away is the way to skip.
                Button("Done") {
                    #if os(iOS)
                    healthDraft?.send(weightKG: weightKG)
                    #endif
                    dismiss()
                }
            }
        }
    }
}

#if os(iOS)
/// A finished session as it will go to Apple Health: when it started, how long
/// it ran, and how hard. Held by the summary, so its Done can send what the
/// card shows.
///
/// Light by default every time. It is the safer guess — a session with rests
/// between sets is nearer the Compendium's light figure, and overstating what
/// was burned invites eating it back — so Vigorous is a choice made for the
/// session in front of you, not a setting that quietly carries over.
@MainActor
@Observable
final class HealthWorkoutDraft {
    let session: WorkoutSession
    let start: Date
    var minutes: Int
    var effort: WorkoutEnergy.Effort = .light

    init(session: WorkoutSession, window: (start: Date, duration: TimeInterval, basis: WorkoutEnergy.DurationBasis)) {
        self.session = session
        self.start = window.start
        self.minutes = max(1, Int((window.duration / 60).rounded()))
    }

    var duration: TimeInterval { TimeInterval(minutes) * 60 }

    func kilocalories(weightKG: Double?) -> Double {
        WorkoutEnergy.activeKilocalories(effort: effort, weightKG: weightKG ?? 0, duration: duration)
    }

    /// Under five minutes is not the session, so it is not sent.
    var canSend: Bool { WorkoutEnergy.check(duration) != .tooShort }

    /// Hands the session to the sync, which carries on after the summary has
    /// closed.
    func send(weightKG: Double?) {
        guard canSend else { return }
        let session = session, start = start, duration = duration
        let kilocalories = kilocalories(weightKG: weightKG)
        Task {
            await HealthSync.shared.write(session, start: start, duration: duration, kilocalories: kilocalories)
        }
    }
}

/// What the summary's Done will send to Apple Health, laid out first.
///
/// The duration is first logged set to last — or the session's clock, when the
/// sets were logged too close together to say — so it is shown, checked and
/// editable; and the effort is the one part no clock can know.
private struct HealthWorkoutSection: View {
    @Bindable var draft: HealthWorkoutDraft
    let unitSystem: UnitSystem

    @Environment(\.senkuBodyWeightKG) private var weightKG

    var body: some View {
        Section {
            // Light on one side, Vigorous on the other, the switch between
            // them — two choices read as a sentence rather than a control.
            HStack(spacing: 12) {
                Text(WorkoutEnergy.Effort.light.title)
                    .fontWeight(draft.effort == .light ? .semibold : .regular)
                    .foregroundStyle(draft.effort == .light ? Color.primary : Color.secondary)
                Toggle("Vigorous", isOn: Binding(
                    get: { draft.effort == .vigorous },
                    set: { draft.effort = $0 ? .vigorous : .light }
                ))
                .labelsHidden()
                .tint(RootView.Tab.workout.tint)
                Text(WorkoutEnergy.Effort.vigorous.title)
                    .fontWeight(draft.effort == .vigorous ? .semibold : .regular)
                    .foregroundStyle(draft.effort == .vigorous ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            // The duration and anything wrong with it, as one row.
            VStack(alignment: .leading, spacing: 4) {
                Stepper(value: $draft.minutes, in: 1...600, step: 5) {
                    LabeledContent("Duration", value: "\(draft.minutes) min")
                }
                switch WorkoutEnergy.check(draft.duration) {
                case .tooShort:
                    Text("Under 5 minutes — set how long you actually trained.")
                        .font(.footnote)
                        .foregroundStyle(Senku.Palette.warning)
                case .unusuallyLong:
                    Text("Over 3 hours — check this is the session, not when finish was tapped.")
                        .font(.footnote)
                        .foregroundStyle(Senku.Palette.caution)
                case .plausible:
                    EmptyView()
                }
            }

            if weightKG != nil {
                LabeledContent("Energy", value: "≈ \(Int(draft.kilocalories(weightKG: weightKG).rounded())) kcal")
            } else {
                Text("Log a weigh-in to estimate the energy. The workout is still sent without it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Apple Health")
        }
    }
}
#endif

private struct SenkuBodyWeightKey: EnvironmentKey {
    static let defaultValue: Double? = nil
}

extension EnvironmentValues {
    /// The latest body weight, in kilograms, for estimating a workout's energy.
    /// Set once at the root; nil until there is a weigh-in or a profile.
    public var senkuBodyWeightKG: Double? {
        get { self[SenkuBodyWeightKey.self] }
        set { self[SenkuBodyWeightKey.self] = newValue }
    }
}

/// Which exercise the logging sheet is for.
///
/// A type of its own rather than a retroactive `Identifiable` on `String`:
/// conforming a standard type in a library is a decision that leaks into every
/// file that imports it, and this one is needed by exactly one sheet.
private struct LoggingTarget: Identifiable {
    let id: String
}

/// Logging a cardio session: the clock, and whatever that machine reports.
///
/// No sets, no reps, no weight. What goes in is the time you were on it and the
/// two or three figures the display was showing when you got off — which is
/// what a treadmill actually gives you, and all anyone reliably remembers a
/// minute later.
///
/// The fields come from the exercise: speed and incline for a treadmill,
/// distance and split for a rower, nothing at all for skipping. A generic set
/// of cardio fields would be three-quarters blank on every machine.
private struct CardioLogger: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseID: String
    @Bindable var workouts: WorkoutStore
    @Bindable var cardioRecords: CardioRecordStore
    @Bindable var library: ExerciseLibrary
    let unitSystem: UnitSystem

    @State private var newRecord: CardioRecord?
    @State private var minutes: Double = 20
    @State private var values: [String: Double] = [:]
    @State private var hasSeeded = false

    private var exercise: Exercise? { library.exercise(exerciseID) }
    private var metrics: [CardioMetric] { exercise?.cardioMetrics ?? [] }
    private var entry: WorkoutEntry? { workouts.live?.entry(exerciseID) }

    var body: some View {
        Form {
            Section {
                Stepper(value: $minutes, in: 1...240, step: 1) {
                    LabeledContent("Time") {
                        Text("\(Int(minutes)) min")
                            .monospacedDigit()
                    }
                }

                ForEach(metrics) { metric in
                    LabeledContent(metric.title) {
                        HStack {
                            TextField(
                                metric.title,
                                value: binding(for: metric),
                                format: .number.precision(.fractionLength(0...metric.decimals))
                            )
                            #if os(iOS)
                            .keyboardType(metric.decimals == 0 ? .numberPad : .decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)

                            let unit = metric.unit(metric: unitSystem == .metric)
                            if !unit.isEmpty {
                                Text(unit)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } footer: {
                if let previous = lastEffort {
                    Text("Last time: " + Display.cardio(previous, for: exercise, in: unitSystem))
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    Label(entry?.cardio == nil ? "Log it" : "Update", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Senku.Palette.protein)

                if entry?.cardio != nil {
                    Button(role: .destructive) {
                        workouts.logCardio(nil, for: exerciseID, records: nil)
                        dismiss()
                    } label: {
                        Text("Clear").frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle(library.name(of: exerciseID))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            guard !hasSeeded else { return }
            hasSeeded = true
            seed()
        }
    }

    private func binding(for metric: CardioMetric) -> Binding<Double?> {
        Binding(
            get: { values[metric.rawValue] },
            set: { newValue in
                // A cleared field is an absent value, never a zero — "I did not
                // look at the distance" must not become "I covered none".
                if let newValue {
                    values[metric.rawValue] = newValue
                } else {
                    values.removeValue(forKey: metric.rawValue)
                }
            }
        )
    }

    /// Today's entry if there is one, otherwise the last time you did this.
    private func seed() {
        if let current = entry?.cardio {
            minutes = (current.seconds / 60).rounded()
            values = current.values
        } else if let previous = lastEffort {
            minutes = (previous.seconds / 60).rounded()
            values = previous.values
        }
    }

    private var lastEffort: CardioEffort? {
        workouts.lastEntry(forExercise: exerciseID)?.1.cardio
    }

    private func save() {
        guard let effort = try? CardioEffort(seconds: minutes * 60, values: values) else { return }
        Feedback.control()
        newRecord = workouts.logCardio(effort, for: exerciseID, records: cardioRecords)
        dismiss()
    }
}

/// "Go heavier": the last time this exercise was done, it met the target.
///
/// The step is the smallest one nearly every gym can make — 2.5 kg, or 5 lb —
/// whatever the exercise. A machine with a 5 kg stack will need the figure
/// changing, and that is one edit in the logger rather than a setting per
/// exercise. A bodyweight movement steps up in reps instead.
struct StepUp {
    let fromKG: Double
    let toKG: Double

    var isBodyweight: Bool { fromKG == 0 }

    static func earned(
        for exerciseID: String,
        in workouts: WorkoutStore,
        target: RepTarget,
        unitSystem: UnitSystem
    ) -> StepUp? {
        guard let (_, last) = workouts.lastEntry(forExercise: exerciseID),
              let top = last.earnedStepUp(for: target)
        else { return nil }

        guard top > 0 else { return StepUp(fromKG: 0, toKG: 0) }
        let step = unitSystem == .metric ? 2.5 : Convert.kilograms(fromPounds: 5)
        return StepUp(fromKG: top, toKG: top + step)
    }

    /// "try 42.5 kg" — short enough for the checklist row.
    func hint(in system: UnitSystem) -> String {
        isBodyweight ? "try more reps" : "try \(Display.lifted(toKG, in: system))"
    }

    func explanation(target: RepTarget, in system: UnitSystem) -> String {
        let hit = "Last time you did \(target.sets)×\(target.topReps)"
        return isBodyweight
            ? "\(hit). Go for more reps."
            : "\(hit) at \(Display.lifted(fromKG, in: system)). Go up to \(Display.lifted(toKG, in: system))."
    }
}
#endif
