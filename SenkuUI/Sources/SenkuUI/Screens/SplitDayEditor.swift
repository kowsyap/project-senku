#if !os(watchOS)
import SwiftUI
import SenkuCore

/// One day of the plan: its name, the muscles it is for, and the movements.
///
/// The coverage section is the reason this screen is worth opening. Picking
/// exercises from a list is a task any app can offer; saying "that is 54% of a
/// back, and the half you are missing is lats" is the thing Senku knows how to
/// do, and it belongs next to the choice rather than in a report afterwards.
struct SplitDayEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var day: SplitDay
    @Bindable private var store: TrainingPlanStore
    @Bindable private var library: ExerciseLibrary

    private let isNew: Bool

    @State private var adding: WorkoutGroup?
    @State private var info: Exercise?

    init(
        day: SplitDay,
        store: TrainingPlanStore,
        library: ExerciseLibrary,
        isNew: Bool = false
    ) {
        _day = State(initialValue: day)
        self.store = store
        self.library = library
        self.isNew = isNew
    }

    private var exercises: [Exercise] {
        day.exerciseIDs.compactMap { library.exercise($0) }
    }

    private var canSave: Bool {
        !day.name.trimmingCharacters(in: .whitespaces).isEmpty && !day.groups.isEmpty
    }

    var body: some View {
        Form {
            nameSection
            groupSection

            if !day.groups.isEmpty {
                coverageSection
                strandedSection
            }
        }
        .navigationTitle(isNew ? "New Day" : day.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .sheet(item: $adding) { group in
            NavigationStack {
                ExercisePicker(
                    library: library,
                    hidden: Set(day.exerciseIDs),
                    startingIn: group,
                    deletionRefusal: deletionRefusal
                ) { exercise in
                    day.exerciseIDs.append(exercise.id)
                    adding = nil
                }
                .navigationTitle("Add to \(group.title)")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { adding = nil }
                    }
                }
            }
        }
        .sheet(item: $info) { exercise in
            NavigationStack {
                ExerciseContribution(
                    exercise: exercise,
                    within: exercises,
                    groups: day.groups,
                    catalogue: library.catalogue,
                )
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            TextField("Name", text: $day.name, prompt: Text("Pull"))
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif
        } header: {
            Text("Call it something")
        }
    }

    /// The seven groups as a wrapping row of glyphs, tapped to include.
    ///
    /// Multi-select and order-free: "chest and triceps" is the same day as
    /// "triceps and chest", and making it a list with checkmarks would spend a
    /// screenful on seven words the icons already say.
    private var groupSection: some View {
        Section {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 74), spacing: 10)],
                spacing: 10
            ) {
                ForEach(library.catalogue.workoutGroups) { group in
                    groupTile(group)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Muscles this day is for")
        }
    }

    private func groupTile(_ group: WorkoutGroup) -> some View {
        let isOn = day.groups.contains(group)

        return Button {
            if isOn {
                day.groups.removeAll { $0 == group }
            } else {
                day.groups.append(group)
            }
        } label: {
            VStack(spacing: 4) {
                GroupGlyph(group: group, size: 30)
                Text(group.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isOn ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(group.tint.opacity(isOn ? 0.22 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(group.tint.opacity(isOn ? 0.9 : 0), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.title)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    /// What this day trains, and — since there is no separate list any more —
    /// where its exercises are added and removed.
    ///
    /// One section rather than two. A flat list above the coverage said the
    /// same names twice and answered the less interesting question: "what is in
    /// this day" is a list anyone can keep in their head, while "what does it
    /// train, and which movement is doing it" is the thing worth a screen. So
    /// the muscles are the structure and the exercises live inside them.
    private var coverageSection: some View {
        ForEach(day.groups) { group in
            let picked = MuscleCoverage.contributors(
                among: exercises,
                to: group,
                in: library.catalogue
            )
            let suggestions = MuscleCoverage.suggestions(
                for: group,
                given: exercises,
                in: library.catalogue,
                limit: 2
            )

            Section {
                CoverageRow(
                    coverage: MuscleCoverage.of(exercises, for: group, in: library.catalogue),
                    contributors: picked,
                    onInspect: { info = $0 },
                    onRemove: { exercise in
                        // Removed from the day, not from this muscle: an
                        // exercise listed under two groups is one entry, and
                        // pretending otherwise would let the same tap mean
                        // different things in different rows.
                        day.exerciseIDs.removeAll { $0 == exercise.id }
                    },
                    onAdd: { adding = group }
                )
            }

            // Suggestions sit outside the card on purpose. What is in the card
            // is the day as it stands; a suggestion is a thing the app is
            // offering, and giving it the same white ground would make Senku's
            // opinion look like your own choices.
            if !suggestions.isEmpty {
                Section {
                    SuggestionStrip(group: group, suggestions: suggestions) { exercise in
                        day.exerciseIDs.append(exercise.id)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                #if os(iOS)
                .listSectionSpacing(.compact)
                #endif
            }
        }
    }

    /// Exercises in the day that none of its muscles account for.
    ///
    /// The case that makes this necessary: pick a chest day, add dips, then
    /// remove chest from the day's muscles. Without a home of their own those
    /// exercises would simply stop being drawn — still in the day, still on the
    /// checklist, and impossible to get rid of from the one screen that is
    /// supposed to manage them.
    @ViewBuilder
    private var strandedSection: some View {
        let covered = Set(
            day.groups.flatMap { group in
                MuscleCoverage.contributors(among: exercises, to: group, in: library.catalogue)
                    .map(\.exercise.id)
            }
        )
        let stranded = exercises.filter { !covered.contains($0.id) }

        if !stranded.isEmpty {
            Section {
                ForEach(stranded) { exercise in
                    HStack {
                        Text(exercise.name)
                        Spacer()
                        Button {
                            day.exerciseIDs.removeAll { $0 == exercise.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Also in this day")
            }
        }
    }

    // MARK: - Actions

    private func save() {
        day.name = day.name.trimmingCharacters(in: .whitespaces)
        if isNew {
            store.add(day)
        } else {
            store.update(day)
        }
        dismiss()
    }

    /// Deleting an exercise the plan names would leave a checklist row nothing
    /// can label — so it is refused rather than cascaded. Records are a
    /// different matter and are guarded separately, on the PR page.
    private func deletionRefusal(_ exercise: Exercise) -> String? {
        if day.exerciseIDs.contains(exercise.id) {
            return "“\(exercise.name)” is in this day. Remove it from the list first."
        }
        guard store.isUsed(exercise: exercise.id) else { return nil }
        return "“\(exercise.name)” is in another day of your plan. Take it out there first."
    }
}

/// One group's coverage: the number, the bar, and the way to improve it.
private struct CoverageRow: View {
    let coverage: MuscleCoverage
    let contributors: [(exercise: Exercise, fraction: Double)]
    let onInspect: (Exercise) -> Void
    let onRemove: (Exercise) -> Void
    let onAdd: () -> Void

    private var tint: Color { coverage.group.tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                GroupGlyph(group: coverage.group, size: 22)
                Text(coverage.group.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(coverage.percentage)%")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            ProgressView(value: coverage.fraction)
                .tint(tint)

            // The exercises doing the work, under the muscle they work — a
            // triceps movement that trains chest is listed here too, which is
            // the only way the number above adds up to what is shown.
            ForEach(contributors, id: \.exercise.id) { entry in
                HStack(spacing: 8) {
                    Button {
                        onRemove(entry.exercise)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(entry.exercise.name)")

                    Button {
                        onInspect(entry.exercise)
                    } label: {
                        HStack(spacing: 8) {
                            Text(entry.exercise.name)
                                .font(.subheadline)
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)

                            Spacer(minLength: 8)
                            Text("\(Int((entry.fraction * 100).rounded()))%")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if !coverage.gaps.isEmpty {
                Text("Missing: " + coverage.gaps.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Bottom right, in the muscle's own colour: the action belongs to
            // this card and to no other, and a full-width row would have read
            // as a list item rather than as this group's button.
            HStack {
                Spacer()
                Button(action: onAdd) {
                    Label("Exercise", systemImage: "plus")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(tint.opacity(0.18), in: .capsule)
                        .foregroundStyle(tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add an exercise to \(coverage.group.title)")
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

/// What the app would add next, offered outside the card.
private struct SuggestionStrip: View {
    let group: WorkoutGroup
    let suggestions: [(exercise: Exercise, gain: Double)]
    let onAdd: (Exercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(suggestions, id: \.exercise.id) { suggestion in
                Button {
                    onAdd(suggestion.exercise)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text(suggestion.exercise.name)
                            .lineLimit(1)
                        Text("+\(Int((suggestion.gain * 100).rounded()))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                    }
                    .font(.caption.weight(.medium))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(group.tint)
            }
        }
        .padding(.top, 2)
    }
}

/// What one exercise is doing for this day.
///
/// The marginal figure rather than the raw contribution: a second flat press
/// looks substantial on its own and adds almost nothing after the first, and
/// someone deciding what to cut needs the second number, not the first.
private struct ExerciseContribution: View {
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise
    let within: [Exercise]
    let groups: [WorkoutGroup]
    let catalogue: ExerciseCatalogue

    var body: some View {
        List {
            Section {
                Text(exercise.name).font(.headline)
                if !exercise.description.isEmpty {
                    Text(exercise.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Equipment", value: exercise.equipment.title)
            }

            Section {
                ForEach(groups) { group in
                    let marginal = MuscleCoverage.marginalValue(
                        of: exercise,
                        within: within,
                        for: group,
                        in: catalogue
                    )
                    LabeledContent(group.title) {
                        Text(marginal < 0.005 ? "nothing it does not already have" : "\(Int((marginal * 100).rounded()))%")
                            .foregroundStyle(marginal < 0.005 ? .secondary : .primary)
                    }
                }
            } header: {
                Text("Dropping this would cost")
            }

            Section {
                ForEach(exercise.targetMuscles, id: \.self) { muscle in
                    Text(muscle)
                }
            } header: {
                Text("Trains")
            } footer: {
                if exercise.isCustom {
                    Text("You classified this exercise, so these figures rest on your own reading of it rather than on the catalogue.")
                }
            }
        }
        .navigationTitle("Contribution")
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
#endif
