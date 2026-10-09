#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Choosing an exercise: muscle group first, then the movement.
///
/// Two steps rather than one long list. A hundred and sixty exercises in a single
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

    @State private var group: WorkoutGroup?
    /// The one group this picker offers, when it was opened for one.
    private let fence: WorkoutGroup?
    @State private var search = ""
    @State private var info: Exercise?
    @State private var isCreating = false
    /// Ring or body, for choosing the group. Remembered, because whichever one
    /// somebody prefers they will prefer every time.
    @AppStorage(GroupPickerStyle.storageKey, store: SenkuStorage.shared)
    private var groupStyle: GroupPickerStyle = .body
    /// How far the ring has been turned by hand, in radians. Kept while the
    /// picker is open, so going into a group and back finds it where you left
    /// it; a new picker starts from the anatomical order again.
    @State private var ringRotation: Double = 0
    /// The previous touch point of a turn in progress. Turning is summed from
    /// one point to the next rather than measured from where the finger began,
    /// so a drag that goes more than halfway round keeps going the same way.
    @State private var lastRingPoint: CGPoint?

    public init(
        library: ExerciseLibrary,
        hidden: Set<String> = [],
        /// Offers one group and nothing else, for a caller that already knows
        /// which muscle is being filled — "add to chest" shows chest, and its
        /// search looks in chest. A day that wants something from outside its
        /// muscles has its own way in, the Other card, which opens on the
        /// groups.
        within group: WorkoutGroup? = nil,
        deletionRefusal: @escaping (Exercise) -> String? = { _ in nil },
        onPick: @escaping (Exercise) -> Void
    ) {
        self.library = library
        self.hidden = hidden
        self.deletionRefusal = deletionRefusal
        self.onPick = onPick
        self.fence = group
        _group = State(initialValue: group)
    }

    private func available(in group: WorkoutGroup) -> [Exercise] {
        library.exercises(in: group).filter { !hidden.contains($0.id) }
    }

    /// An opaque sheet colour. `.background` inside a sheet resolves to the
    /// sheet's own glass, so it cannot be used to replace it.
    static var solidSheet: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    private var searchResults: [Exercise] {
        guard !search.isEmpty else { return [] }
        // By any name it goes by, not only the catalogue's: "skull crusher"
        // has to find the lying triceps extension, or search fails the one
        // person who knew exactly what they wanted.
        return library.all
            .filter { !hidden.contains($0.id) && $0.matches(search) }
            .filter { fence == nil || $0.workoutGroup == fence }
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
        .searchable(text: $search, prompt: fence.map { "Search \($0.title)" } ?? "Search all exercises")
        .navigationTitle(group == nil ? "Muscle Group" : "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // Not for a fenced picker: it has nowhere else to go.
            if fence == nil, group != nil, search.isEmpty {
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
            // Solid, not the half-height sheet's default glass: in dark mode
            // the glass came out a washed grey with the list showing through,
            // and the grey text and the Done on it all but disappeared.
            .presentationBackground(Self.solidSheet)
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
    /// Chest is the centre, and the ring runs clockwise from noon —
    /// shoulders, biceps, forearms, abs, legs, back, triceps. It reads as a
    /// body rather than a list: shoulders on top, the arm running down the
    /// right from biceps to forearm, abs low on the front, legs at the bottom,
    /// and back and triceps up the left where the posterior work belongs.
    ///
    /// It was six around one until forearms became a group. Seven spaces the
    /// ring at a seventh of a turn instead of a sixth, which is less tidy on
    /// paper and reads just the same in the hand.
    ///
    /// The ring is not load-bearing: a catalogue whose groups are not exactly
    /// these falls back to a grid rather than a ring with a hole in it.
    private var groupPicker: some View {
        // Cardio is not a muscle and does not belong in a ring of them. It
        // stands apart as a heart in the corner — the same place in both
        // styles — so the shape itself says "this is a different kind of
        // thing" before its name is even read.
        let muscles = library.catalogue.workoutGroups.filter(\.isMuscle)
        let others = library.catalogue.workoutGroups.filter { !$0.isMuscle }
        let ringOrder: [WorkoutGroup] = [.shoulder, .bicep, .forearm, .abs, .legs, .back, .tricep]
        let canRing = muscles.count == ringOrder.count + 1 && Set(muscles) == Set(ringOrder + [.chest])

        // Cardio is the heart in the corner, in both styles; any other group
        // that is not a muscle keeps a bar of its own under the ring.
        let bars = others.filter { $0 != .cardio }
        let pick: (WorkoutGroup) -> Void = { picked in
            withAnimation(.snappy(duration: 0.2)) { group = picked }
        }

        return VStack(spacing: 0) {
            // Outside the scroll view, so the switch stays put and the ring
            // can be centred in exactly the space below it.
            Picker("Choose by", selection: $groupStyle.animation(.snappy(duration: 0.2))) {
                ForEach(GroupPickerStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            GeometryReader { geometry in
                ScrollView {
                    switch groupStyle {
                    case .body:
                        BodyMapPicker(available: geometry.size, onPick: pick)
                    case .ring:
                        VStack(spacing: 14) {
                            if canRing {
                                ring(around: .chest, others: ringOrder)
                            } else {
                                grid(muscles)
                            }

                            ForEach(bars) { other in
                                wideButton(other)
                            }
                        }
                        // At least as tall as the space, so a ring smaller
                        // than it sits in the middle of it.
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                }
                // Cardio's heart: the same tile as the ring's discs, in the
                // same corner whichever style is showing, so it is one fixed
                // thing rather than part of either.
                .overlay(alignment: .bottomLeading) {
                    if others.contains(.cardio) {
                        tileButton(.cardio, diameter: Self.ringTile)
                            .padding(.leading, 22)
                            // Standing on the same line as the body map's
                            // figures, in both styles.
                            .padding(.bottom, BodyMapPicker.groundInset(in: geometry.size))
                    }
                }
            }
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
        // Sized so neighbours sit as far apart as the six-group ring's did —
        // a seventh tile narrows the gap between centres, so the tiles shrink
        // and the ring widens to win it back. 346 points still fits a 375-point
        // phone.
        let radius: CGFloat = 124
        let tile = Self.ringTile
        let side = 2 * radius + tile + 20
        let centrePoint = CGPoint(x: side / 2, y: side / 2)
        let step = 2 * Double.pi / Double(max(others.count, 1))

        return RingLayout(radius: radius, rotation: ringRotation) {
            tileButton(centre, diameter: tile)
            ForEach(others) { candidate in
                tileButton(candidate, diameter: tile)
            }
        }
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        // Turned by dragging round it. High priority so a drag that starts on
        // a tile turns the ring instead of being lost to the tile's button or
        // the scroll view; a tap moves too little to count as a drag, so it
        // still picks the group.
        .highPriorityGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    let previous = lastRingPoint ?? value.startLocation
                    lastRingPoint = value.location
                    ringRotation += Self.turn(from: previous, to: value.location, around: centrePoint)
                }
                .onEnded { value in
                    lastRingPoint = nil
                    // A flick carries on a little, at most two places, and the
                    // ring always settles with a group exactly at the top.
                    let fling = Self.turn(from: value.location, to: value.predictedEndLocation, around: centrePoint)
                    let carried = ringRotation + min(max(fling, -2 * step), 2 * step)
                    withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                        ringRotation = (carried / step).rounded() * step
                    }
                }
        )
        // A tick each time a group passes the top.
        .sensoryFeedback(.selection, trigger: Int((ringRotation / step).rounded()))
        .frame(maxWidth: .infinity)
    }

    /// A disc in the ring — and the cardio heart, which is sized to match.
    static let ringTile: CGFloat = 78

    /// The angle swept going from one point to the next, seen from the centre.
    ///
    /// Zero near the centre itself, where a finger's smallest movement is a
    /// huge angle and the ring would lurch.
    nonisolated static func turn(from a: CGPoint, to b: CGPoint, around centre: CGPoint) -> Double {
        let u = CGVector(dx: a.x - centre.x, dy: a.y - centre.y)
        let v = CGVector(dx: b.x - centre.x, dy: b.y - centre.y)
        guard hypot(u.dx, u.dy) > 30, hypot(v.dx, v.dy) > 30 else { return 0 }
        return atan2(u.dx * v.dy - u.dy * v.dx, u.dx * v.dx + u.dy * v.dy)
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
                    // Why it is here at all, when the search was for a name
                    // that is not this one's: "skull" turning up "Lying EZ-Bar
                    // Triceps Extension" otherwise looks like a wrong result.
                    if let alias = exercise.alias(matching: search) {
                        Text("Also called \(alias)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(subtitle(for: exercise))
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
/// The two ways of choosing a group: the ring of discs, or the body.
enum GroupPickerStyle: String, CaseIterable, Identifiable {
    // Body first: it is the default, and the switch lists it first.
    case body
    case ring

    static let storageKey = "senku.picker.groupStyle.v1"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ring: "Groups"
        case .body: "Body"
        }
    }
}

/// One view in the middle and the rest on a circle round it, turned by
/// `rotation`.
///
/// A layout rather than offsets on a stack, because a layout's animatable data
/// is the angle itself: when the ring springs to rest, each tile travels along
/// the circle. Animated offsets would move them in straight lines, cutting
/// across the middle on any turn of more than a place or two. The tiles are
/// moved round, never rotated, so their labels stay upright.
private struct RingLayout: Layout {
    var radius: CGFloat
    /// Radians, clockwise. Zero puts the first ring view at noon.
    var rotation: Double

    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let centre = CGPoint(x: bounds.midX, y: bounds.midY)
        guard let middle = subviews.first else { return }
        middle.place(at: centre, anchor: .center, proposal: .unspecified)

        let ring = subviews.dropFirst()
        let step = 2 * Double.pi / Double(max(ring.count, 1))
        for (index, subview) in ring.enumerated() {
            let angle = Double(index) * step - .pi / 2 + rotation
            subview.place(
                at: CGPoint(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle)),
                anchor: .center,
                proposal: .unspecified
            )
        }
    }
}

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

                        if !exercise.aliases.isEmpty {
                            Text("Also called \(exercise.aliases.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Card("Trains") {
                        ForEach(trained, id: \.name) { region in
                            StatRow(
                                region.name,
                                value: "\(Int((region.share * 100).rounded()))%",
                                tint: region.share >= 0.8 ? Senku.Palette.protein : nil
                            )
                        }

                        // The same percentages, on the body: only what this
                        // works is coloured, yellow for a little, red for the
                        // muscle it is *the* exercise for.
                        if (BodyMapPart.front + BodyMapPart.back).contains(where: { $0.share(of: exercise.contributions) != nil }) {
                            BodyHighlight { part in
                                part.share(of: exercise.contributions).map(BodyHighlight.heat)
                            }
                            .frame(height: 230)
                            .padding(.top, 6)

                            HStack(spacing: 14) {
                                BodyHighlightKey(color: BodyHighlight.heat(0.2), label: "Little")
                                BodyHighlightKey(color: BodyHighlight.heat(0.6), label: "Some")
                                BodyHighlightKey(color: BodyHighlight.heat(1), label: "Most")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Card("Equipment") {
                        StatRow("Uses", value: exercise.equipment.title)
                        StatRow("Group", value: exercise.workoutGroup.title)
                        // Cardio is always logged as time and its own metrics,
                        // so the line would only ever say the same thing.
                        if !exercise.isCardio {
                            StatRow("Logged as", value: exercise.isTimed ? "Time held" : "Reps")
                        }
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
                    // The text colour rather than the page's accent: the PR
                    // page's indigo, on a dark button, was barely there.
                    Button("Done", action: onClose)
                        .fontWeight(.semibold)
                        .tint(.primary)
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
    @State private var isTimed = false

    private let equipmentChoices: [Equipment] = [.barbell, .dumbbell, .kettlebell, .machine, .cable, .bodyweight]

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

                // Not offered for cardio, which is logged as time already and
                // would only be asking the same question twice.
                if chosenGroup != .cardio {
                    Section {
                        Toggle("Timed", isOn: $isTimed)
                    } footer: {
                        Text(isTimed
                             ? "Sets are logged as seconds held — a dead hang, a carry, a plank."
                             : "Sets are logged as reps. Turn this on for something you hold rather than repeat.")
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
            .navigationTitle("Your Exercise")
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
                            regions: picked,
                            isTimed: isTimed && chosenGroup != .cardio
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
