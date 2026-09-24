#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Setting up the week: what days you train, and what you do on each.
///
/// Reached once and then rarely. That shapes it: this screen can afford to be
/// long and explanatory in a way the screen you open mid-set cannot, and it is
/// where the coverage figures belong — deciding that your pull day is 62% of a
/// back is a thing to do on a sofa, not between sets.
public struct PlanSetupView: View {
    @Bindable private var store: TrainingPlanStore
    @Bindable private var library: ExerciseLibrary

    @State private var editing: SplitDay?
    @State private var isAddingDay = false
    @State private var deleting: SplitDay?

    public init(store: TrainingPlanStore, library: ExerciseLibrary) {
        self.store = store
        self.library = library
    }

    public var body: some View {
        Group {
            if store.hasPlan {
                dayList
            } else {
                templateChooser
            }
        }
        .senkuBottomBarInset()
        .navigationTitle("Your Week")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if store.hasPlan {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingDay = true
                    } label: {
                        StackedActionLabel("Add", symbol: "plus")
                    }
                }
            }
        }
        .sheet(item: $editing) { day in
            NavigationStack {
                SplitDayEditor(day: day, store: store, library: library)
            }
        }
        .sheet(isPresented: $isAddingDay) {
            NavigationStack {
                SplitDayEditor(
                    day: SplitDay(name: "", groups: []),
                    store: store,
                    library: library,
                    isNew: true
                )
            }
        }
        .confirmationDialog(
            "Delete “\(deleting?.name ?? "")”?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete day", role: .destructive) {
                if let deleting { store.delete(deleting) }
                deleting = nil
            }
            Button("Keep", role: .cancel) { deleting = nil }
        } message: {
            Text("Workouts you have already logged are kept.")
        }
    }

    // MARK: - Starting from nothing

    /// The first thing anyone sees here, and the only screen in the app that
    /// hands you a whole structure at once.
    ///
    /// Templates carry days and muscle groups but no exercises, so adopting one
    /// is a head start rather than a decision made for you: you still choose
    /// every movement, which is the part that depends on your gym and your
    /// shoulders.
    private var templateChooser: some View {
        List {
            Section {
                ForEach(SplitTemplate.allCases) { template in
                    Button {
                        store.adopt(template)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(template.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            groupRow(template.days.flatMap(\.groups))
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Start from a shape")
            } footer: {
                Text("These set the days and the muscles. You pick the exercises.")
            }

            Section {
                Button {
                    isAddingDay = true
                } label: {
                    Label("Build my own", systemImage: "square.and.pencil")
                }
            }
        }
    }

    // MARK: - The plan

    private var dayList: some View {
        List {
            Section {
                ForEach(store.days) { day in
                    Button {
                        editing = day
                    } label: {
                        dayRow(day)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleting = day
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { store.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Days")
            }

            if !store.plan.untrainedGroups.isEmpty {
                Section {
                    groupRow(store.plan.untrainedGroups)
                } header: {
                    // Stated, not scolded: leaving legs out may be a choice.
                    Text("Not in your week")
                }
            }
        }

    }

    private func dayRow(_ day: SplitDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day.name.isEmpty ? "Untitled day" : day.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(day.isEmpty ? "No exercises" : "\(day.exerciseIDs.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            groupRow(day.groups)

            if !day.isEmpty {
                Text(coverageSummary(for: day))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func groupRow(_ groups: [WorkoutGroup]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(Set(groups)).sorted(by: { $0.rawValue < $1.rawValue })) { group in
                GroupGlyph(group: group, size: 22)
            }
        }
    }

    /// "Back 71% · Biceps 90%" — the day's own report card.
    private func coverageSummary(for day: SplitDay) -> String {
        let exercises = day.exerciseIDs.compactMap { library.exercise($0) }
        return day.groups
            .map { group in
                let coverage = MuscleCoverage.of(exercises, for: group, in: library.catalogue)
                return "\(group.title) \(coverage.percentage)%"
            }
            .joined(separator: " · ")
    }
}
#endif
