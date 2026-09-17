#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Every lift you have a record on.
///
/// A record, not a plan: this outlives whatever split you are running, and
/// nothing you change about your training removes anything from it. An exercise
/// appears here because you once lifted something on it, and stays.
public struct RecordsView: View {
    @State private var store: RecordStore
    @State private var isAdding = false
    @State private var detail: ExerciseRecords?

    @State private var library: ExerciseLibrary
    private let unitSystem: UnitSystem

    public init(
        store: RecordStore = RecordStore(),
        library: ExerciseLibrary = ExerciseLibrary(),
        unitSystem: UnitSystem = .metric
    ) {
        _store = State(initialValue: store)
        _library = State(initialValue: library)
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

    public var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                if store.records.isEmpty {
                    empty
                } else {
                    ForEach(sections, id: \.group) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(section.group.title, systemImage: section.group.symbol)
                                .font(.footnote.weight(.semibold))
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            ForEach(section.entries) { record in
                                Button {
                                    detail = record
                                } label: {
                                    recordCard(record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
        .sheet(isPresented: $isAdding) {
            RecordEditor(
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
        .sheet(item: $detail) { entry in
            RecordDetailSheet(
                entry: entry,
                name: name(of: entry.exerciseID),
                isBodyweight: library.exercise(entry.exerciseID)?.equipment == .bodyweight,
                unitSystem: unitSystem,
                onDelete: { store.delete($0) },
                onAdd: { store.add($0) },
                onDeleteExercise: {
                    store.deleteAll(forExercise: entry.exerciseID)
                    detail = nil
                },
                onClose: { detail = nil }
            )
        }
    }

    private func recordCard(_ entry: ExerciseRecords) -> some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(name(of: entry.exerciseID))
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)

                    Text(subtitle(for: entry.exerciseID))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.leading)

                    if let heaviest = entry.heaviest {
                        Text("\(heaviest.date.formatted(.relative(presentation: .named)))\(heaviest.source.isLogged ? "" : " · typed in")")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 8)

                if let heaviest = entry.heaviest {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(lift(heaviest))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(Senku.Palette.protein)

                        if let best = entry.bestEstimated {
                            // Named, because it is a formula's answer rather
                            // than a lift that happened.
                            Text("~\(Display.mass(best.estimatedOneRepMax, in: unitSystem, decimals: 0)) est. 1RM")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
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

    /// How a lift reads. A pull-up is not "0.0 kg × 12" — it is twelve
    /// pull-ups, and added weight is written as the addition it is.
    private func lift(_ record: PersonalRecord) -> String {
        let isBodyweight = library.exercise(record.exerciseID)?.equipment == .bodyweight

        if record.isBodyweightOnly {
            return "Bodyweight × \(record.reps)"
        }
        let weight = Display.mass(record.weightKG, in: unitSystem)
        return isBodyweight
            ? "+\(weight) × \(record.reps)"
            : "\(weight) × \(record.reps)"
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
    let entry: ExerciseRecords
    let name: String
    let isBodyweight: Bool
    let unitSystem: UnitSystem
    let onDelete: (PersonalRecord) -> Void
    let onAdd: (PersonalRecord) -> Void
    let onDeleteExercise: () -> Void
    let onClose: () -> Void

    @State private var isAdding = false
    @State private var deleting: PersonalRecord?
    @State private var isConfirmingExerciseDelete = false

    private func row(for record: PersonalRecord) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(lift(record))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                Text(record.source.isLogged ? "From a logged set" : "Typed in")
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

    private func lift(_ record: PersonalRecord) -> String {
        if record.isBodyweightOnly { return "Bodyweight × \(record.reps)" }
        let weight = Display.mass(record.weightKG, in: unitSystem)
        return isBodyweight ? "+\(weight) × \(record.reps)" : "\(weight) × \(record.reps)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Senku.Metrics.stackSpacing) {
                    Card("Best") {
                        if let heaviest = entry.heaviest {
                            StatRow(
                                "Heaviest",
                                value: lift(heaviest),
                                detail: heaviest.date.formatted(date: .abbreviated, time: .omitted),
                                isProminent: true,
                                tint: Senku.Palette.protein
                            )
                        }
                        if let best = entry.bestEstimated {
                            StatRow(
                                "Estimated 1RM",
                                value: Display.mass(best.estimatedOneRepMax, in: unitSystem),
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
                    onDeleteExercise()
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
                    if let deleting { onDelete(deleting) }
                    deleting = nil
                }
                Button("Keep it", role: .cancel) { deleting = nil }
            } message: {
                if let deleting {
                    Text("\(lift(deleting)) on \(deleting.date.formatted(date: .abbreviated, time: .omitted)).")
                }
            }
            .sheet(isPresented: $isAdding) {
                RecordValueEditor(
                    exerciseID: entry.exerciseID,
                    previous: entry.heaviest,
                    isBodyweight: isBodyweight,
                    unitSystem: unitSystem
                ) { added in
                    onAdd(added)
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
    /// Your best so far, which the fields start at: the next record is nearly
    /// always a small step from the last.
    let previous: PersonalRecord?
    let isBodyweight: Bool
    let unitSystem: UnitSystem
    let onSave: (PersonalRecord) -> Void
    let onCancel: () -> Void

    @State private var weight: Double?
    @State private var reps: Double?
    @State private var date = Date.now

    init(
        exerciseID: String,
        previous: PersonalRecord?,
        isBodyweight: Bool,
        unitSystem: UnitSystem,
        onSave: @escaping (PersonalRecord) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.exerciseID = exerciseID
        self.previous = previous
        self.isBodyweight = isBodyweight
        self.unitSystem = unitSystem
        self.onSave = onSave
        self.onCancel = onCancel

        _weight = State(
            initialValue: previous.map {
                unitSystem == .metric ? $0.weightKG : Convert.pounds(fromKilograms: $0.weightKG)
            }
        )
        _reps = State(initialValue: previous.map { Double($0.reps) })
    }

    private var weightKG: Double? {
        guard let weight else { return isBodyweight ? 0 : nil }
        return unitSystem == .metric ? weight : Convert.kilograms(fromPounds: weight)
    }

    private var canSave: Bool {
        reps != nil && (weightKG != nil || isBodyweight)
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
                HStack {
                    Text(isBodyweight ? "Added weight" : "Weight").font(.subheadline)
                    Spacer(minLength: 8)
                    NumericField(
                        value: $weight,
                        range: weightRange,
                        decimals: 1,
                        unit: unitSystem.massLabel,
                        placeholder: isBodyweight ? "0" : "—",
                        identifier: "field.newRecordWeight"
                    )
                }

                Divider()

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

                Divider()

                DatePicker("When", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .font(.subheadline)
            }

            if let previous {
                Text("Your best so far: \(Display.mass(previous.weightKG, in: unitSystem)) × \(previous.reps).")
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
        guard let weightKG, let reps,
              let record = try? PersonalRecord(
                  exerciseID: exerciseID,
                  weightKG: weightKG,
                  reps: Int(reps),
                  date: date,
                  source: .manual
              )
        else { return }
        onSave(record)
    }
}


/// Starting a lift you do not yet track: pick the exercise, then say what you
/// did on it.
///
/// Exercises you already have a record on are not offered here — the next
/// record on those is a dated line inside the exercise itself.
private struct RecordEditor: View {
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
                if let chosen {
                    RecordValueEditor(
                        exerciseID: chosen.id,
                        previous: nil,
                        isBodyweight: chosen.equipment == .bodyweight,
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
