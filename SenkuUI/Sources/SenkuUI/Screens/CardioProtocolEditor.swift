#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Building the table: name the columns, fill the rows.
///
/// Laid out as a real grid that scrolls sideways, rather than as a form of
/// labelled fields, because a ladder is read *down* a column — the point of
/// writing it this way is to see the speed climbing 3, 5, 3, 5, 7 at a glance,
/// and a vertical list of "Block 3 speed: 5" destroys exactly that.
struct CardioProtocolEditor: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseName: String
    @Bindable var store: CardioProtocolStore

    @State private var plan: CardioProtocol
    @State private var isAddingColumn = false
    @State private var newColumn = ""
    @State private var renaming: Int?
    @State private var renamedColumn = ""
    @State private var isConfirmingDelete = false

    private let isNew: Bool

    init(exerciseID: String, exerciseName: String, store: CardioProtocolStore) {
        self.exerciseName = exerciseName
        self.store = store

        let existing = store.plan(for: exerciseID)
        self.isNew = existing == nil
        _plan = State(initialValue: existing ?? CardioProtocol(exerciseID: exerciseID))
    }

    private let cellWidth: CGFloat = 92

    var body: some View {
        Form {
            Section {
                table
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                Text("Your plan")
            }

            Section {
                Button {
                    plan.addRow()
                } label: {
                    Label("Add row", systemImage: "plus")
                }

                Button {
                    isAddingColumn = true
                } label: {
                    Label("Add column", systemImage: "plus.square.on.square")
                }
            }

            Section {
                TextField("Notes", text: $plan.note, axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text("Notes")
            }

            if !isNew {
                Section {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Text("Delete this plan").frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle(exerciseName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.save(plan)
                    dismiss()
                }
            }
        }
        .alert(
            "Rename column",
            isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
        ) {
            TextField("Resist", text: $renamedColumn)
            Button("Rename") {
                if let renaming { plan.renameColumn(at: renaming, to: renamedColumn) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        } message: {
            Text("The figures under it stay where they are.")
        }
        .alert("Name the column", isPresented: $isAddingColumn) {
            TextField("Incline", text: $newColumn)
            Button("Add") {
                plan.addColumn(newColumn)
                newColumn = ""
            }
            Button("Cancel", role: .cancel) { newColumn = "" }
        }
        .alert("Delete this plan?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                store.delete(forExercise: plan.exerciseID)
                dismiss()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("The workouts you logged on this machine are kept.")
        }
    }

    // MARK: - The grid

    private var table: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 4) {
                headerRow

                ForEach(plan.rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 4) {
                        ForEach(plan.columns.indices, id: \.self) { columnIndex in
                            TextField(
                                "",
                                text: Binding(
                                    get: { plan.cells(at: rowIndex)[columnIndex] },
                                    set: { plan.set($0, row: rowIndex, column: columnIndex) }
                                )
                            )
                            .multilineTextAlignment(.center)
                            .font(.system(.body, design: .rounded))
                            .frame(width: cellWidth)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.secondary.opacity(0.10))
                            )
                        }

                        Button {
                            plan.removeRow(at: rowIndex)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete row \(rowIndex + 1)")
                    }
                }

                if !plan.rows.isEmpty {
                    Divider()
                    HStack(spacing: 4) {
                        ForEach(plan.columns.indices, id: \.self) { index in
                            let total = plan.totals.first { $0.column == plan.columns[index] }

                            VStack(alignment: .leading, spacing: 0) {
                                Text(total.map { $0.isSum ? "TOTAL" : "MAX" } ?? "")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundStyle(.tertiary)
                                Text(total?.text ?? "—")
                                    .font(.system(.body, design: .rounded).weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(WorkoutGroup.cardio.tint)
                            }
                            .frame(width: cellWidth)
                        }
                    }
                    .padding(.top, 2)
                }

                if plan.rows.isEmpty {
                    Text("No rows yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 4) {
            ForEach(plan.columns.indices, id: \.self) { index in
                Menu {
                    Button {
                        renamedColumn = plan.columns[index]
                        renaming = index
                    } label: {
                        Label("Rename column", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        plan.removeColumn(at: index)
                    } label: {
                        Label("Delete column", systemImage: "trash")
                    }
                    .disabled(plan.columns.count <= 1)
                } label: {
                    Text(plan.columns[index])
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: cellWidth)
                        .padding(.vertical, 4)
                }
            }
        }
    }
}

/// A protocol as it reads on the PR page: the grid, not editable.
struct CardioProtocolCard: View {
    let plan: CardioProtocol

    private let cellWidth: CGFloat = 78

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        ForEach(plan.columns.indices, id: \.self) { index in
                            Text(plan.columns[index])
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.secondary)
                                .frame(width: cellWidth, alignment: .leading)
                        }
                    }

                    ForEach(plan.rows.indices, id: \.self) { rowIndex in
                        // A rule under every row. A ladder is read across —
                        // "two minutes at five, on an eleven incline" — and
                        // without a line the eye slides between rows on the
                        // way over, which is exactly the mistake that has you
                        // running the wrong block.
                        Divider()

                        HStack(spacing: 4) {
                            ForEach(plan.columns.indices, id: \.self) { columnIndex in
                                Text(plan.cells(at: rowIndex)[columnIndex])
                                    .font(.system(.subheadline, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.primary)
                                    .frame(width: cellWidth, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 3)
                    }

                    totalsRow
                }
            }

            if !plan.note.isEmpty {
                Text(plan.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// What the ladder comes to: the time added up, everything else at its
    /// highest. Set apart by a heavier rule, because it is a different kind of
    /// line from the blocks above it.
    @ViewBuilder
    private var totalsRow: some View {
        let totals = plan.totals

        if !totals.isEmpty {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
                .padding(.top, 2)

            HStack(spacing: 4) {
                ForEach(plan.columns.indices, id: \.self) { index in
                    let total = totals.first { $0.column == plan.columns[index] }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(total.map { $0.isSum ? "total" : "max" } ?? "")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.tertiary)
                        Text(total?.text ?? "—")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(WorkoutGroup.cardio.tint)
                    }
                    .frame(width: cellWidth, alignment: .leading)
                }
            }
            .padding(.top, 3)
        }
    }
}

/// One cardio exercise, opened: what you have done, and the plan you follow.
///
/// The plan sits inside the exercise rather than beside it on the list, because
/// it is reference material — you look it up when you are about to do the
/// session, which is exactly when you are already looking at this exercise.
struct CardioDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseID: String
    let name: String
    let exercise: Exercise?
    @Bindable var records: CardioRecordStore
    @Bindable var protocols: CardioProtocolStore
    let unitSystem: UnitSystem

    @State private var isEditingPlan = false
    @State private var isAdding = false
    @State private var deleting: CardioRecord?

    private var entry: CardioExerciseRecords { records.book.records(for: exerciseID) }
    private var plan: CardioProtocol? { protocols.plan(for: exerciseID) }

    var body: some View {
        List {
            Section {
                if let plan, !plan.isEmpty {
                    CardioProtocolCard(plan: plan)
                        .padding(.vertical, 4)
                }

                Button {
                    isEditingPlan = true
                } label: {
                    Label(
                        plan == nil ? "Add a plan" : "Edit plan",
                        systemImage: plan == nil ? "plus" : "square.and.pencil"
                    )
                }
            } header: {
                Text("Plan")
            }

            Section {
                ForEach(entry.records) { record in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line(for: record))
                            .font(.system(.body, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.primary)
                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            deleting = record
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button {
                    isAdding = true
                } label: {
                    Label("Add a session", systemImage: "plus")
                }
            } header: {
                Text("Records")
            }
        }
        .navigationTitle(name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $isEditingPlan) {
            NavigationStack {
                CardioProtocolEditor(
                    exerciseID: exerciseID,
                    exerciseName: name,
                    store: protocols
                )
            }
        }
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                CardioValueEditor(
                    exercise: exercise,
                    unitSystem: unitSystem,
                    onSave: { record in
                        records.add(record)
                        isAdding = false
                    },
                    onCancel: { isAdding = false }
                )
            }
        }
        .alert(
            "Delete this session?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let deleting { records.delete(deleting) }
                deleting = nil
            }
            Button("Keep", role: .cancel) { deleting = nil }
        }
    }

    private func line(for record: CardioRecord) -> String {
        guard let effort = try? CardioEffort(
            seconds: record.seconds,
            values: record.values,
            completedAt: record.date
        ) else {
            return "\(Int((record.seconds / 60).rounded())) min"
        }
        return Display.cardio(effort, for: exercise, in: unitSystem)
    }
}

/// Typing in a cardio session by hand.
struct CardioValueEditor: View {
    let exercise: Exercise?
    let unitSystem: UnitSystem
    let onSave: (CardioRecord) -> Void
    let onCancel: () -> Void

    @State private var minutes: Double = 20
    @State private var values: [String: Double] = [:]
    @State private var date = Date.now

    private var metrics: [CardioMetric] { exercise?.cardioMetrics ?? [] }

    var body: some View {
        Form {
            Section {
                Stepper(value: $minutes, in: 1...240, step: 1) {
                    LabeledContent("Time") {
                        Text("\(Int(minutes)) min").monospacedDigit()
                    }
                }

                ForEach(metrics) { metric in
                    LabeledContent(metric.title) {
                        HStack {
                            TextField(
                                metric.title,
                                value: Binding(
                                    get: { values[metric.rawValue] },
                                    set: { newValue in
                                        if let newValue {
                                            values[metric.rawValue] = newValue
                                        } else {
                                            values.removeValue(forKey: metric.rawValue)
                                        }
                                    }
                                ),
                                format: .number.precision(.fractionLength(0...metric.decimals))
                            )
                            #if os(iOS)
                            .keyboardType(metric.decimals == 0 ? .numberPad : .decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)

                            let unit = metric.unit(metric: unitSystem == .metric)
                            if !unit.isEmpty {
                                Text(unit).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                DatePicker("When", selection: $date, displayedComponents: .date)
            }
        }
        .navigationTitle(exercise?.name ?? "Session")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let exercise,
                          let record = try? CardioRecord(
                              exerciseID: exercise.id,
                              seconds: minutes * 60,
                              values: values,
                              date: date
                          )
                    else { return }
                    onSave(record)
                }
                .disabled(exercise == nil)
            }
        }
    }
}
#endif
