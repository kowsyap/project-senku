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
    let onFinish: (WorkoutSession) -> Void

    @State private var logging: LoggingTarget?
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
                        unitSystem: unitSystem
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
                    workouts.addExercise(exercise.id)
                    isAdding = false
                }
                .navigationTitle("Add to today")
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
        .confirmationDialog(
            "Finish this workout?",
            isPresented: $isConfirmingFinish,
            titleVisibility: .visible
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
                Text(library.name(of: entry.exerciseID))
                    .font(.body.weight(.medium))
                    .foregroundStyle(entry.isSkipped ? Color.secondary : Color.primary)
                    .strikethrough(entry.isSkipped)

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
        }
        .padding(.vertical, 2)
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
                .map { "\(Display.mass($0.weightKG, in: unitSystem, decimals: 0))×\($0.reps)" }
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
        return "Last: \(figure), \(session.date.formatted(.relative(presentation: .named)))"
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
                        TextField(
                            "Weight",
                            value: $weight,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                        Text(unitSystem.massLabel)
                            .foregroundStyle(.secondary)
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
        }
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

    let session: WorkoutSession
    @Bindable var library: ExerciseLibrary
    let unitSystem: UnitSystem

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
            } header: {
                Text("What you trained")
            } footer: {
                Text("Measured on the exercises you actually logged.")
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
                Button("Done") { dismiss() }
            }
        }
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
#endif
