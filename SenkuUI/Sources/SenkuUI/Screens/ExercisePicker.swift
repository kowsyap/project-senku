#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Choosing an exercise: muscle group first, then the movement.
///
/// Two steps rather than one long list. Seventy-six exercises in a single
/// alphabetical column is a scroll nobody reads, and the first thing anyone
/// knows when they pick an exercise is which muscle they are there for — so
/// that is the question asked first. Search is still there for the person who
/// knows exactly what they want and would rather type it.
public struct ExercisePicker: View {
    @Bindable private var library: ExerciseLibrary
    private let onPick: (Exercise) -> Void

    /// Why a custom exercise cannot be deleted, if it cannot.
    ///
    /// Supplied by the caller because the picker has no business knowing what
    /// else refers to an exercise. The requirements doc settles the rule it
    /// enforces: deleting a movement that a personal record points at is
    /// refused, with the reason said out loud, rather than quietly leaving a
    /// record whose name nothing can resolve.
    private let deletionRefusal: (Exercise) -> String?

    /// Exercises that already have a record, and so are not offered again.
    ///
    /// A second record on the same lift is not a new entry in this list — it is
    /// a new line in that exercise's own history, added from inside it. Showing
    /// the exercise twice at the top level would make the list a log of
    /// attempts rather than a list of lifts.
    private let hidden: Set<String>

    /// The group the caller fixed, if it fixed one. Distinct from ``group``,
    /// which is where the user currently is.
    private let pinnedGroup: WorkoutGroup?

    @State private var group: WorkoutGroup?
    @State private var search = ""
    @State private var info: Exercise?
    @State private var isCreating = false

    public init(
        library: ExerciseLibrary,
        hidden: Set<String> = [],
        /// Opens straight into one group, for a caller that already knows which
        /// muscle is being filled — "add to chest" should not begin by asking
        /// which muscle you meant.
        startingIn group: WorkoutGroup? = nil,
        deletionRefusal: @escaping (Exercise) -> String? = { _ in nil },
        onPick: @escaping (Exercise) -> Void
    ) {
        self.library = library
        self.hidden = hidden
        self.deletionRefusal = deletionRefusal
        self.onPick = onPick
        self.pinnedGroup = group
        _group = State(initialValue: group)
    }

    private func available(in group: WorkoutGroup) -> [Exercise] {
        library.exercises(in: group).filter { !hidden.contains($0.id) }
    }

    private var searchResults: [Exercise] {
        guard !search.isEmpty else { return [] }
        return library.all
            .filter { !hidden.contains($0.id) && $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name < $1.name }
    }

    public var body: some View {
        Group {
            if search.isEmpty, group == nil {
                groupPicker
            } else {
                exerciseList
            }
        }
        .searchable(text: $search, prompt: "Search all exercises")
        .navigationTitle(group == nil ? "Muscle group" : "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // Only when there is somewhere to go back *to*. Opened from a
            // workout day the group is the caller's, not a step the user took,
            // and a chevron there would offer to undo something they never did
            // — landing them in a group picker they did not ask for, with no
            // way back to the day.
            if group != nil, pinnedGroup == nil, search.isEmpty {
                ToolbarItem(placement: .cancellationAction) {
                    // A chevron, as a pushed screen would have. The word
                    // "Groups" named where the tap goes, but this is the one
                    // control on iOS that needs no naming — and it stops the
                    // row reading as two competing labels beside the title.
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { self.group = nil }
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Back to muscle groups")
                }
            }
        }
        // A half-height sheet rather than a popover. A popover on a phone is a
        // narrow bubble with an arrow, and the description ran to two lines
        // inside a box sized for a tooltip; a detent gives the text the width
        // of the screen and still leaves the list behind it.
        .sheet(item: $info) { exercise in
            ExerciseInfoSheet(
                exercise: exercise,
                library: library,
                refusal: deletionRefusal(exercise),
                onDelete: exercise.isCustom
                    ? {
                        library.delete(exercise)
                        info = nil
                    }
                    : nil,
                onClose: { info = nil }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isCreating) {
            CustomExerciseEditor(library: library, group: group) { created in
                library.add(created)
                isCreating = false
                onPick(created)
            } onCancel: {
                isCreating = false
            }
            // Tied to the group it was opened from, so the editor is rebuilt
            // — and its group preselected — rather than reusing the state of a
            // previous presentation from somewhere else in the list.
            .id(group?.rawValue ?? "allGroups")
        }
    }

    /// The groups, arranged as a ring around one.
    ///
    /// Seven is the number that makes this work: six around one, at sixty
    /// degrees apart, which is the only tidy arrangement of seven things and
    /// happens to be what the body offers.
    ///
    /// Chest is the centre, and the ring runs clockwise from noon —
    /// shoulders, biceps, abs, legs, back, triceps. It reads as a body rather
    /// than a list: shoulders on top, abs low on the front, legs at the bottom,
    /// and back and triceps up the left where the posterior work belongs.
    ///
    /// The ring is not load-bearing: a catalogue with any other number of
    /// groups falls back to a grid rather than a broken circle.
    private var groupPicker: some View {
        // Cardio is not a muscle and does not belong in a ring of them. It sits
        // below, as a bar rather than a disc, so the shape itself says "this is
        // a different kind of thing" before the heart on it is even read.
        let muscles = library.catalogue.workoutGroups.filter(\.isMuscle)
        let others = library.catalogue.workoutGroups.filter { !$0.isMuscle }
        let ringOrder: [WorkoutGroup] = [.shoulder, .bicep, .abs, .legs, .back, .tricep]
        let canRing = muscles.count == 7 && Set(muscles) == Set(ringOrder + [.chest])

        return ScrollView {
            VStack(spacing: 14) {
                if canRing {
                    ring(around: .chest, others: ringOrder)
                } else {
                    grid(muscles)
                }

                ForEach(others) { other in
                    wideButton(other)
                }
            }
            .padding(.bottom, 12)
        }
        .background(.background)
    }

    /// A group that is not a muscle: full width, a heart, its own colour.
    private func wideButton(_ candidate: WorkoutGroup) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { group = candidate }
        } label: {
            HStack(spacing: 12) {
                GroupGlyph(group: candidate, size: 26)
                    .frame(width: 44, height: 44)
                    .background(candidate.tint.opacity(0.16), in: .circle)

                Text(candidate.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(candidate.tint.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityLabel(candidate.title)
    }

    private func ring(around centre: WorkoutGroup, others: [WorkoutGroup]) -> some View {
        let radius: CGFloat = 108
        let tile: CGFloat = 86

        return ZStack {
            tileButton(centre, diameter: tile)

            ForEach(Array(others.enumerated()), id: \.element) { index, candidate in
                // Clockwise from noon: shoulders at the top, arms down the
                // right, legs at the bottom, back and abs up the left.
                let angle = Angle.degrees(Double(index) * 60 - 90)
                tileButton(candidate, diameter: tile)
                    .offset(
                        x: radius * cos(angle.radians),
                        y: radius * sin(angle.radians)
                    )
            }
        }
        .frame(width: 2 * radius + tile + 20, height: 2 * radius + tile + 20)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func grid(_ groups: [WorkoutGroup]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
            ForEach(groups) { tileButton($0, diameter: 92) }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// One group: the mark on a tinted disc, its name beneath.
    private func tileButton(_ candidate: WorkoutGroup, diameter: CGFloat) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { group = candidate }
        } label: {
            VStack(spacing: 3) {
                GroupGlyph(group: candidate, size: diameter * 0.62)
                    .frame(width: diameter, height: diameter)
                    .background(candidate.tint.opacity(0.12), in: .circle)

                Text(candidate.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
    }

    private var exerciseList: some View {
        List {
            if !search.isEmpty {
                Section("Matches") {
                    ForEach(searchResults) { row($0) }
                }
            } else if let group {
                Section {
                    VStack(spacing: 4) {
                        GroupGlyph(group: group, size: 54)
                            .frame(height: 54)
                        Text(group.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                // A list row carries its own insets, and a section its own gap
                // above and below. Both were padding this header out to twice
                // its content — the space was the list's, not the view's.
                .listRowInsets(EdgeInsets())

                Section {
                    if available(in: group).isEmpty {
                        Text("Every \(group.title.lowercased()) exercise already has a record. Open it from the list to add another.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(available(in: group)) { row($0) }
                    }
                }

                Section {
                    Button {
                        isCreating = true
                    } label: {
                        Label("Add your own to \(group.title)", systemImage: "plus.circle")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        #if os(iOS)
        .listSectionSpacing(.compact)
        #endif
    }

    /// Equipment and the muscles it trains, in one line — what you need to
    /// tell two similar names apart without opening either.
    private func subtitle(for exercise: Exercise) -> String {
        let muscles = exercise.contributions
            .sorted { $0.value > $1.value }
            .prefix(3)
            .compactMap { library.catalogue.region($0.key)?.name }

        let parts = [exercise.isCustom ? "Yours" : nil, exercise.equipment.title]
            .compactMap { $0 } + [muscles.joined(separator: ", ")]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func row(_ exercise: Exercise) -> some View {
        HStack(spacing: 10) {
            Button {
                onPick(exercise)
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    // Said explicitly, because a button's label otherwise takes
                    // the accent colour of wherever the picker was opened from
                    // — green inside the workout tab, violet from the PR page —
                    // and an exercise's name is content, not a link.
                    Text(exercise.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle(for: exercise))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                info = exercise
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Senku.Palette.protein)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("How \(exercise.name) is done")
        }
    }
}

/// What the ⓘ shows: how it is done, and what it trains.
struct ExerciseInfoSheet: View {
    let exercise: Exercise
    let library: ExerciseLibrary
    /// Set when deleting is refused, and shown as the reason.
    let refusal: String?
    /// nil for catalogue exercises, which are not yours to delete.
    let onDelete: (() -> Void)?
    let onClose: () -> Void

    @State private var isConfirmingDelete = false
    @State private var isShowingRefusal = false

    private var trained: [(name: String, share: Double)] {
        exercise.contributions
            .sorted { $0.value > $1.value }
            .compactMap { id, value in
                library.catalogue.region(id).map { (name: $0.name, share: value) }
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Senku.Metrics.stackSpacing) {
                    Card("How it is done") {
                        Text(exercise.description.isEmpty
                             ? "No description — this is one of yours."
                             : exercise.description)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Card("Trains") {
                        ForEach(trained, id: \.name) { region in
                            StatRow(
                                region.name,
                                value: "\(Int((region.share * 100).rounded()))%",
                                tint: region.share >= 0.8 ? Senku.Palette.protein : nil
                            )
                        }

                        Text("How much of each muscle this movement trains, where 100% means it is *the* exercise for it.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Card("Equipment") {
                        StatRow("Uses", value: exercise.equipment.title)
                        StatRow("Group", value: exercise.workoutGroup.title)
                    }

                    if exercise.isCustom {
                        Text("Muscles as you classified them, so anything Senku measures from this is an estimate rather than a catalogue figure.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)


                    }
                }
                .padding()
            }
            .background(.background)
            .navigationTitle(exercise.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                // Beside the title rather than buried under the content: it is
                // an action on the thing named at the top, and finding it
                // should not require reading to the bottom of a sheet.
                if onDelete != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            if refusal == nil {
                                isConfirmingDelete = true
                            } else {
                                isShowingRefusal = true
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(Senku.Palette.warning)
                        .accessibilityLabel("Delete this exercise")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
            .confirmationDialog(
                "Delete \(exercise.name)?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { onDelete?() }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("This removes the exercise from your list. It cannot be undone.")
            }
            .alert("Not yet", isPresented: $isShowingRefusal) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(refusal ?? "")
            }
        }
    }
}

/// Making one up.
struct CustomExerciseEditor: View {
    @Bindable var library: ExerciseLibrary
    let group: WorkoutGroup?
    let onSave: (Exercise) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var chosenGroup: WorkoutGroup
    @State private var equipment: Equipment = .barbell
    @State private var regionIDs: Set<String> = []

    private let equipmentChoices: [Equipment] = [.barbell, .dumbbell, .machine, .cable, .bodyweight]

    init(
        library: ExerciseLibrary,
        group: WorkoutGroup?,
        onSave: @escaping (Exercise) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.library = library
        self.group = group
        self.onSave = onSave
        self.onCancel = onCancel
        _chosenGroup = State(initialValue: group ?? .chest)
    }

    private var regions: [MuscleRegion] { library.catalogue.regions(in: chosenGroup) }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !regionIDs.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Landmine press", text: $name)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                }

                Section("Group") {
                    Picker("Group", selection: $chosenGroup) {
                        ForEach(library.catalogue.workoutGroups) { Text($0.title).tag($0) }
                    }
                    .onChange(of: chosenGroup) { _, _ in regionIDs = [] }
                }

                Section("Equipment") {
                    // Not segmented: five options across a phone clipped
                    // "Bodyweight" to "Bodyweig…". A menu has room for the
                    // longest word whatever the device.
                    Picker("Equipment", selection: $equipment) {
                        ForEach(equipmentChoices, id: \.self) { Text($0.title).tag($0) }
                    }
                }

                Section {
                    ForEach(regions) { region in
                        Button {
                            if regionIDs.contains(region.id) {
                                regionIDs.remove(region.id)
                            } else {
                                regionIDs.insert(region.id)
                            }
                        } label: {
                            HStack {
                                Text(region.name).font(.subheadline)
                                Spacer(minLength: 8)
                                if regionIDs.contains(region.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Senku.Palette.protein)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("What it trains")
                } footer: {
                    // The app's measured-versus-estimated rule, applied to a
                    // movement nobody has classified but you.
                    Text("Senku scores coverage from these. Because you picked them rather than the catalogue, anything measured from this exercise is an estimate.")
                }
            }
            .navigationTitle("Your exercise")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let picked = regions.filter { regionIDs.contains($0.id) }
                        guard let exercise = Exercise.custom(
                            name: name.trimmingCharacters(in: .whitespaces),
                            equipment: equipment,
                            regions: picked
                        ) else { return }
                        onSave(exercise)
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
#endif
