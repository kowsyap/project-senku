#if !os(watchOS)
import SwiftUI
import SenkuCore

/// An exercise id, for `sheet(item:)`.
private struct ExerciseID: Identifiable, Hashable {
    let id: String

    init(_ id: String) { self.id = id }
}

/// Every lift you have a record on.
///
/// A record, not a plan: this outlives whatever split you are running, and
/// nothing you change about your training removes anything from it. An exercise
/// appears here because you once lifted something on it, and stays.
public struct RecordsView: View {
    @State private var store: RecordStore
    @State private var isAdding = false
    /// Which exercise's history is open, by id.
    ///
    /// Not the `ExerciseRecords` value itself: that is a snapshot computed from
    /// the store, so a sheet holding one went on showing the records as they
    /// were when it opened while adding and deleting changed the store behind
    /// it. An id is the only part that does not go stale.
    @State private var detailID: ExerciseID?

    @State private var library: ExerciseLibrary
    @State private var protocols: CardioProtocolStore
    @State private var cardioRecords: CardioRecordStore
    private let unitSystem: UnitSystem

    /// Which cardio plan is open for editing.
    @State private var editingProtocol: ExerciseID?
    @State private var filter: WorkoutGroup?

    public init(
        store: RecordStore = RecordStore(),
        library: ExerciseLibrary = ExerciseLibrary(),
        protocols: CardioProtocolStore = CardioProtocolStore(),
        cardioRecords: CardioRecordStore = CardioRecordStore(),
        unitSystem: UnitSystem = .metric
    ) {
        _store = State(initialValue: store)
        _library = State(initialValue: library)
        _protocols = State(initialValue: protocols)
        _cardioRecords = State(initialValue: cardioRecords)
        self.unitSystem = unitSystem
    }

    /// Records gathered under the muscle they belong to, newest first inside
    /// each.
    ///
    /// The All / Recent / Stale filter is gone: every row carries its own date,
    /// so "recent" was a control that hid rows to tell you something the rows
    /// already said. Sorting by it does the same work and loses nothing.
    private var sections: [(group: WorkoutGroup, entries: [ExerciseRecords])] {
        let grouped = Dictionary(grouping: store.book.byExercise) { entry in
            library.exercise(entry.exerciseID)?.workoutGroup ?? WorkoutGroup("other")
        }

        return library.catalogue.workoutGroups.compactMap { group in
            guard let entries = grouped[group], !entries.isEmpty else { return nil }
            return (
                group: group,
                entries: entries.sorted {
                    ($0.mostRecent?.date ?? .distantPast) > ($1.mostRecent?.date ?? .distantPast)
                }
            )
        }
    }

    /// The groups you actually have records in, as chips.
    ///
    /// Built from the records rather than from the catalogue: a filter for a
    /// muscle you have never logged is a button that can only ever empty the
    /// screen.
    @ViewBuilder
    private var groupFilter: some View {
        let groups = availableGroups

        if groups.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", tint: Senku.Palette.carbs, isOn: filter == nil) { filter = nil }

                    ForEach(groups) { group in
                        chip(group.title, tint: group.tint, isOn: filter == group) {
                            filter = filter == group ? nil : group
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private func chip(
        _ label: String,
        tint: Color,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(tint.opacity(isOn ? 0.25 : 0.10), in: .capsule)
                .foregroundStyle(isOn ? tint : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private var availableGroups: [WorkoutGroup] {
        var groups = sections.map(\.group)
        if !cardioRecords.records.isEmpty { groups.append(.cardio) }
        return library.catalogue.workoutGroups.filter { groups.contains($0) }
    }

    /// The lifts on screen: everything, or one group's worth, newest first.
    private var shownRecords: [ExerciseRecords] {
        sections
            .filter { filter == nil || $0.group == filter }
            .flatMap(\.entries)
    }

    /// Cardio, in the same shape as the rest of the page: one card per
    /// exercise, headlined by the figure that exercise is measured in.
    ///
    /// That figure is **time**. There is no single "best" on a machine — a hard
    /// twenty minutes beats a gentle forty — so the card leads with the longest
    /// session and names the other bests underneath, and a session counts as a
    /// record when it beats the time *or* any figure the machine reports.
    @ViewBuilder
    private var cardioSection: some View {
        let entries = cardioRecords.book.byExercise

        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entries) { entry in
                    Button {
                        editingProtocol = ExerciseID(entry.exerciseID)
                    } label: {
                        cardioCard(entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func cardioCard(_ entry: CardioExerciseRecords) -> some View {
        let exercise = library.exercise(entry.exerciseID)
        let longest = entry.longest

        // Built to the same shape as `recordCard` rather than to its own: the
        // first version aligned on the first text baseline and glued the unit
        // on with `Text + Text`, which floated the number away from the middle
        // of the row and left a gap above the title. Two cards in one list have
        // to be one card with different contents.
        return Card {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name(of: entry.exerciseID))
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)

                    if let bests = cardioBests(entry, exercise: exercise) {
                        Text(bests)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.leading)
                    }

                    if let date = entry.mostRecent?.date {
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(longest.map { "\(Int(($0.seconds / 60).rounded()))" } ?? "—")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("min")
                        .font(.caption.weight(.semibold))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(WorkoutGroup.cardio.tint)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    /// "Best 8.0 km/h · 12%" — the other figures, if the machine reports any.
    private func cardioBests(_ entry: CardioExerciseRecords, exercise: Exercise?) -> String? {
        let parts = (exercise?.cardioMetrics ?? []).compactMap { metric -> String? in
            guard let best = entry.best(metric) else { return nil }
            let unit = metric.unit(metric: unitSystem == .metric)
            let number = best.formatted(.number.precision(.fractionLength(0...metric.decimals)))
            return unit.isEmpty ? "\(number) \(metric.title.lowercased())" : "\(number) \(unit)"
        }
        return parts.isEmpty ? nil : "Best " + parts.joined(separator: " · ")
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                if store.records.isEmpty, cardioRecords.records.isEmpty {
                    empty
                } else {
                    groupFilter

                    if filter == nil || filter == .cardio {
                        cardioSection
                    }

                    // A flat list, filtered. The headings said the same word as
                    // the chip above them and cost a line each on a page that
                    // is mostly scrolling — and with a filter chosen, a heading
                    // announces the only group on screen.
                    ForEach(shownRecords) { record in
                        Button {
                            detailID = ExerciseID(record.exerciseID)
                        } label: {
                            recordCard(record)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    StackedActionLabel("Add", symbol: "plus")
                }
                .accessibilityLabel("Add a personal record")
            }
        }
        .sheet(item: $editingProtocol) { opened in
            NavigationStack {
                CardioDetailSheet(
                    exerciseID: opened.id,
                    name: name(of: opened.id),
                    exercise: library.exercise(opened.id),
                    records: cardioRecords,
                    protocols: protocols,
                    unitSystem: unitSystem
                )
            }
        }
        .sheet(isPresented: $isAdding) {
            RecordEditor(
                protocols: protocols,
                cardioRecords: cardioRecords,
                onCardioSaved: { isAdding = false },
                unitSystem: unitSystem,
                library: library,
                // Already has a record: the next one goes inside it, dated.
                hidden: Set(store.book.exerciseIDs),
                deletionRefusal: { exercise in
                    let count = store.book.records(for: exercise.id).records.count
                    guard count > 0 else { return nil }
                    // Refused rather than cascaded: a record is a thing that
                    // happened, and deleting the exercise it names would leave
                    // history pointing at nothing.
                    return count == 1
                        ? "You have a personal record on this. Delete the record first."
                        : "You have \(count) personal records on this. Delete them first."
                }
            ) { record in
                store.add(record)
                isAdding = false
            } onCancel: {
                isAdding = false
            }
        }
        .sheet(item: $detailID) { opened in
            RecordDetailSheet(
                store: store,
                exerciseID: opened.id,
                name: name(of: opened.id),
                isBodyweight: library.exercise(opened.id)?.equipment == .bodyweight,
                isTimed: library.exercise(opened.id)?.isTimed == true,
                unitSystem: unitSystem,
                onClose: { detailID = nil }
            )
        }
    }

    private func recordCard(_ entry: ExerciseRecords) -> some View {
        Card {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name(of: entry.exerciseID))
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)

                    Text(subtitle(for: entry.exerciseID))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.leading)

                    if let best = entry.best {
                        Text(best.date.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let best = entry.best {
                    // Right of the name, and as tall as it: the number is what
                    // the row is for, so it is sized to the block beside it
                    // rather than to the text it sits next to.
                    Text(headline(best))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        // In the muscle's own colour, now that the headings are
                        // gone: the tint is what says which group a row belongs
                        // to, and one blue for every lift would have thrown that
                        // away along with them.
                        .foregroundStyle(tint(for: entry.exerciseID))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }

    /// The colour of the muscle a lift belongs to.
    private func tint(for exerciseID: String) -> Color {
        library.exercise(exerciseID)?.workoutGroup.tint ?? Senku.Palette.protein
    }

    private func name(of exerciseID: String) -> String {
        library.name(of: exerciseID)
    }

    /// Equipment and the muscles trained, matching the picker's rows.
    private func subtitle(for exerciseID: String) -> String {
        guard let exercise = library.exercise(exerciseID) else { return "" }
        let muscles = exercise.contributions
            .sorted { $0.value > $1.value }
            .prefix(2)
            .compactMap { library.catalogue.region($0.key)?.name }
        return ([exercise.equipment.title] + muscles).joined(separator: " · ")
    }

    /// The one figure a row shows: what was on the bar.
    ///
    /// A pull-up has nothing on it, so it reads as bodyweight and the rep count
    /// carries the record instead — the only thing that can change when the
    /// load never does.
    private func headline(_ record: PersonalRecord) -> String {
        let isBodyweight = library.exercise(record.exerciseID)?.equipment == .bodyweight

        // A hold leads with the clock. It is the only figure that moves: the
        // weight is usually nothing and the rep count is always one.
        if let seconds = record.seconds {
            return Display.hold(seconds)
        }
        if record.isBodyweightOnly {
            return "× \(record.reps)"
        }
        let weight = Display.tidyMass(record.weightKG, in: unitSystem)
        return isBodyweight ? "+\(weight)" : weight
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No records yet", systemImage: "trophy")
        } description: {
            Text("Add the lifts you already know, and Senku will keep every one you beat. Nothing here is ever removed by changing your training.")
        } actions: {
            Button("Add a record") { isAdding = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - One exercise

private struct RecordDetailSheet: View {
    @Bindable var store: RecordStore
    let exerciseID: String
    let name: String
    let isBodyweight: Bool
    let isTimed: Bool
    let unitSystem: UnitSystem
    let onClose: () -> Void

    /// Recomputed on every change to the store rather than passed in, which is
    /// what makes a record added or deleted here appear here.
    private var entry: ExerciseRecords { store.book.records(for: exerciseID) }

    @State private var isAdding = false
    @State private var deleting: PersonalRecord?
    @State private var isConfirmingExerciseDelete = false

    private func row(for record: PersonalRecord) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(lift(record))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                Text(estimateNote(record))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                deleting = record
            } label: {
                Image(systemName: "trash").font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .accessibilityLabel("Delete this record")
        }
    }

    /// What one record implies as a single, said per row.
    ///
    /// Without this the "Estimated 1RM" above looks stuck: a heavier lift for
    /// fewer reps can imply a *lower* single than a lighter set for eight, so
    /// adding a record legitimately leaves the figure where it was. Showing
    /// each row's own estimate makes it obvious which set the headline came
    /// from, and why a new one did not take it.
    private func estimateNote(_ record: PersonalRecord) -> String {
        let logged = record.source.isLogged ? "From a logged set · " : ""

        if record.isTimed {
            return logged + "Held"
        }
        guard !record.isBodyweightOnly else {
            return logged + "No weight to estimate from"
        }
        guard record.isReliableEstimate else {
            return logged + "Past 10 reps — no estimate"
        }
        guard let estimate = record.estimatedOneRepMax else {
            return logged + "No estimate for this"
        }
        return logged + "≈ \(Display.tidyMass(estimate, in: unitSystem)) single"
    }

    private func lift(_ record: PersonalRecord) -> String {
        if let seconds = record.seconds {
            return record.isBodyweightOnly
                ? Display.hold(seconds)
                : "+\(Display.tidyMass(record.weightKG, in: unitSystem)) · \(Display.hold(seconds))"
        }
        if record.isBodyweightOnly { return "Bodyweight × \(record.reps)" }
        let weight = Display.tidyMass(record.weightKG, in: unitSystem)
        return isBodyweight ? "+\(weight) × \(record.reps)" : "\(weight) × \(record.reps)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Senku.Metrics.stackSpacing) {
                    Card("Best") {
                        if let best = entry.best {
                            StatRow(
                                entry.isTimed ? "Longest" : "Heaviest",
                                value: lift(best),
                                detail: best.date.formatted(date: .abbreviated, time: .omitted),
                                isProminent: true,
                                tint: Senku.Palette.protein
                            )
                        }
                        if let best = entry.bestEstimated, let estimate = best.estimatedOneRepMax {
                            StatRow(
                                "Estimated 1RM",
                                value: Display.tidyMass(estimate, in: unitSystem),
                                detail: "Epley, from \(lift(best))"
                            )
                        }

                    }

                    Card("Every record") {
                        ForEach(entry.records) { record in
                            row(for: record)

                            if record.id != entry.records.last?.id { Divider() }
                        }
                    }
                }
                .padding()
            }
            .background(.background)
            .navigationTitle(name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isConfirmingExerciseDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(Senku.Palette.warning)
                    .accessibilityLabel("Delete every record for this exercise")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add another record for this exercise")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
            .confirmationDialog(
                "Delete every record for \(name)?",
                isPresented: $isConfirmingExerciseDelete,
                titleVisibility: .visible
            ) {
                Button("Delete \(entry.records.count) records", role: .destructive) {
                    store.deleteAll(forExercise: exerciseID)
                    onClose()
                }
                Button("Keep them", role: .cancel) {}
            } message: {
                Text("The exercise stays in your list. Only what you lifted on it is removed, and that cannot be undone.")
            }
            .confirmationDialog(
                "Delete this record?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let deleting { store.delete(deleting) }
                    deleting = nil
                    // The last one gone means there is nothing left to look at.
                    if entry.records.isEmpty { onClose() }
                }
                Button("Keep it", role: .cancel) { deleting = nil }
            } message: {
                if let deleting {
                    Text("\(lift(deleting)) on \(deleting.date.formatted(date: .abbreviated, time: .omitted)).")
                }
            }
            .sheet(isPresented: $isAdding) {
                RecordValueEditor(
                    exerciseID: exerciseID,
                    existing: entry.records,
                    previous: entry.best,
                    isBodyweight: isBodyweight,
                    isTimed: isTimed,
                    unitSystem: unitSystem
                ) { added in
                    store.add(added)
                    isAdding = false
                } onCancel: {
                    isAdding = false
                }
            }
        }
    }
}

/// Adding another record to a lift you already tracked.
///
/// There is no editing, and that is the point: a record is something that
/// happened on a day. Correcting a figure in place would quietly rewrite
/// history, while a new dated line leaves the old one where it was and lets the
/// dates say which is which — the same reason the sheet lists every record
/// rather than only the best one.
private struct RecordValueEditor: View {
    let exerciseID: String
    /// Every record already on this lift, so the same one cannot be logged
    /// twice.
    let existing: [PersonalRecord]
    /// Your best so far, which the fields start at: the next record is nearly
    /// always a small step from the last.
    let previous: PersonalRecord?
    let isBodyweight: Bool
    let isTimed: Bool
    let unitSystem: UnitSystem
    let onSave: (PersonalRecord) -> Void
    let onCancel: () -> Void

    @State private var weight: Double?
    @State private var reps: Double?
    @State private var seconds: TimeInterval
    @State private var date = Date.now

    init(
        exerciseID: String,
        existing: [PersonalRecord] = [],
        previous: PersonalRecord?,
        isBodyweight: Bool,
        isTimed: Bool = false,
        unitSystem: UnitSystem,
        onSave: @escaping (PersonalRecord) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.exerciseID = exerciseID
        self.existing = existing
        self.previous = previous
        self.isBodyweight = isBodyweight
        self.isTimed = isTimed
        self.unitSystem = unitSystem
        self.onSave = onSave
        self.onCancel = onCancel

        _weight = State(
            initialValue: previous.map {
                unitSystem == .metric ? $0.weightKG : Convert.pounds(fromKilograms: $0.weightKG)
            }
        )
        _reps = State(initialValue: previous.map { Double($0.reps) })
        _seconds = State(initialValue: previous?.seconds ?? (isTimed ? 60 : 60))
    }

    private var weightKG: Double? {
        guard let weight else { return isBodyweight ? 0 : nil }
        return unitSystem == .metric ? weight : Convert.kilograms(fromPounds: weight)
    }

    /// The record this would duplicate, if it would.
    private var duplicate: PersonalRecord? {
        guard let weightKG else { return nil }
        if isTimed {
            return RecordBook(existing).existingRecord(
                exerciseID: exerciseID,
                weightKG: weightKG,
                reps: 0,
                seconds: seconds
            )
        }
        guard let reps else { return nil }
        return RecordBook(existing).existingRecord(
            exerciseID: exerciseID,
            weightKG: weightKG,
            reps: Int(reps)
        )
    }

    private var canSave: Bool {
        guard duplicate == nil else { return false }
        guard weightKG != nil || isBodyweight else { return false }
        return isTimed || reps != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView { fields }
                .background(.background)
                .dismissableKeyboard()
                .navigationTitle("New record")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save).disabled(!canSave)
                    }
                }
        }
    }

    private var fields: some View {
        VStack(spacing: Senku.Metrics.stackSpacing) {
            Card("What you lifted") {
                // A bodyweight exercise is reps and nothing else. The field was
                // there for the belt-and-plate case, and it earned its place by
                // making every pull-up entry a decision about a number that is
                // nearly always zero — so it is gone, and a weighted variation
                // is what a custom exercise is for.
                if !isBodyweight {
                    HStack {
                        Text("Weight").font(.subheadline)
                        Spacer(minLength: 8)
                        NumericField(
                            value: $weight,
                            range: weightRange,
                            decimals: 1,
                            unit: unitSystem.massLabel,
                            placeholder: "—",
                            identifier: "field.newRecordWeight"
                        )
                    }

                    Divider()
                }

                if isTimed {
                    // Held, so the figure that moves is the clock. Five-second
                    // steps for the same reason the session logger uses them.
                    Stepper(value: $seconds, in: 5...600, step: 5) {
                        HStack {
                            Text("Hold").font(.subheadline)
                            Spacer()
                            Text(Display.hold(seconds))
                                .font(.headline)
                                .monospacedDigit()
                        }
                    }
                } else {
                    HStack {
                        Text("Reps").font(.subheadline)
                        Spacer(minLength: 8)
                        NumericField(
                            value: $reps,
                            range: 1...100,
                            unit: "reps",
                            identifier: "field.newRecordReps"
                        )
                    }
                }

                Divider()

                DatePicker("When", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .font(.subheadline)
            }

            if let duplicate {
                // Said plainly, with the date, rather than leaving Save dead
                // and the reason to be guessed at.
                Label(
                    "You already have this one, from \(duplicate.date.formatted(date: .abbreviated, time: .omitted)). Change the weight or the reps.",
                    systemImage: "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundStyle(Senku.Palette.caution)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let previous {
                Text("Your best so far: " + Display.set(
                    weightKG: previous.weightKG,
                    reps: previous.reps,
                    seconds: previous.seconds,
                    in: unitSystem
                ) + ".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }

    private var weightRange: ClosedRange<Double> {
        if isBodyweight {
            return unitSystem == .metric ? 0...200 : 0...440
        }
        return unitSystem == .metric ? 1...500 : 2...1100
    }

    private func save() {
        guard let weightKG else { return }

        let record = try? PersonalRecord(
            exerciseID: exerciseID,
            weightKG: weightKG,
            reps: isTimed ? 0 : Int(reps ?? 0),
            seconds: isTimed ? seconds : nil,
            date: date,
            source: .manual
        )
        guard let record else { return }
        onSave(record)
    }
}


/// Starting a lift you do not yet track: pick the exercise, then say what you
/// did on it.
///
/// Exercises you already have a record on are not offered here — the next
/// record on those is a dated line inside the exercise itself.
private struct RecordEditor: View {
    @Bindable var protocols: CardioProtocolStore
    @Bindable var cardioRecords: CardioRecordStore
    let onCardioSaved: () -> Void

    let unitSystem: UnitSystem
    @Bindable var library: ExerciseLibrary
    let hidden: Set<String>
    /// Why one of your own exercises cannot be deleted right now.
    let deletionRefusal: (Exercise) -> String?
    let onSave: (PersonalRecord) -> Void
    let onCancel: () -> Void

    @State private var chosen: Exercise?

    var body: some View {
        NavigationStack {
            Group {
                if let chosen, chosen.isCardio {
                    // Weight and reps mean nothing on a treadmill, so a cardio
                    // record is a time and whatever that machine reports.
                    CardioValueEditor(
                        exercise: chosen,
                        unitSystem: unitSystem,
                        onSave: { record in
                            cardioRecords.add(record)
                            onCardioSaved()
                        },
                        onCancel: { self.chosen = nil }
                    )
                } else if let chosen {
                    RecordValueEditor(
                        exerciseID: chosen.id,
                        previous: nil,
                        isBodyweight: chosen.equipment == .bodyweight,
                        isTimed: chosen.isTimed,
                        unitSystem: unitSystem,
                        onSave: onSave,
                        onCancel: { self.chosen = nil }
                    )
                } else {
                    ExercisePicker(
                        library: library,
                        hidden: hidden,
                        deletionRefusal: deletionRefusal
                    ) { picked in
                        chosen = picked
                    }
                    .navigationTitle("Pick an exercise")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Cancel", action: onCancel)
                        }
                    }
                }
            }
            .background(.background)
        }
    }
}

#endif
