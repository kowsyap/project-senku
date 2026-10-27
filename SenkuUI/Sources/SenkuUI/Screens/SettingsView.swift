#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Settings that belong to the app rather than to any one screen, and a way
/// to every screen's own.
///
/// A screen's settings stay behind that screen's own button — Adjust, or Week
/// and Rack where a plainer name says more — because that is where you are
/// standing when you want to change them — the bottle you drink from
/// is noticed on the water page. This page holds what has no page of its own
/// (how the app is arranged, what it shares with Apple Health) and links to
/// the rest, opening the same pages, so everything can also be found in one
/// place without anything being kept twice.
struct SettingsView: View {
    @Bindable var layout: TabLayout
    let water: WaterStore
    let intake: IntakeStore
    let plans: TrainingPlanStore
    let library: ExerciseLibrary
    let dues: DueDateStore
    let anime: AnimeStore
    let unitSystem: UnitSystem

    /// Opened fresh for the rack editor; the plate calculator reads the
    /// saved rack again when it next appears.
    @State private var plates: PlateStore?
    @AppStorage(DayBoundary.storageKey, store: SenkuStorage.shared) private var dayBoundary = 0
    /// The boundary picked and not yet confirmed. Changing it moves every
    /// day's totals and streaks, so it is asked about first.
    @State private var pendingBoundary: Int?
    #if os(iOS)
    private let health = HealthSync.shared
    #endif

    var body: some View {
        List {
            Section {
                NavigationLink {
                    TabBarEditor(layout: layout)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(RootView.Tab.more.tint)
                            .frame(width: 26)
                        Text("Navbar")
                    }
                }
            }

            Section {
                Picker(selection: Binding(
                    get: { dayBoundary },
                    set: { if $0 != dayBoundary { pendingBoundary = $0 } }
                )) {
                    ForEach(DayBoundary.choices, id: \.self) { hour in
                        Text(DayBoundary.title(hour)).tag(hour)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "moon.stars")
                            .foregroundStyle(RootView.Tab.more.tint)
                            .frame(width: 26)
                        Text("Day starts at")
                    }
                }
            } footer: {
                Text(dayBoundary == 0
                    ? "Logs after midnight count towards the new day."
                    : "Logs before \(DayBoundary.title(dayBoundary)) count towards the previous day.")
            }

            #if os(iOS)
            healthSection
            #endif

            screensSection

            ExtrasSection(extras: .shared, layout: layout, data: ExtraData(dues: dues, anime: anime))

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(RootView.Tab.more.tint)
                            .frame(width: 26)
                        Text("About")
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { plates != nil }, set: { if !$0 { plates = nil } })) {
            if let plates {
                PlateRackEditor(plates: plates, unitSystem: plates.unit) { self.plates = nil }
            }
        }
        .alert(
            "Start the day at \(DayBoundary.title(pendingBoundary ?? 0).lowercased())?",
            isPresented: Binding(get: { pendingBoundary != nil }, set: { if !$0 { pendingBoundary = nil } })
        ) {
            Button("Change") {
                if let pendingBoundary { dayBoundary = pendingBoundary }
                pendingBoundary = nil
            }
            Button("Cancel", role: .cancel) { pendingBoundary = nil }
        } message: {
            Text("Today's totals and your streaks are counted again from the new start of the day. Nothing you logged is changed.")
        }
        // The More tab's grey made the alert's buttons look disabled.
        .tint(.blue)
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .senkuBottomBarInset()
    }

    /// Each screen's own settings, the same pages its button opens: changed
    /// where you notice them, and all findable from here.
    private var screensSection: some View {
        Section {
            NavigationLink {
                PlanSetupView(store: plans, library: library)
            } label: {
                row("Workout", symbol: RootView.Tab.workout.symbol, tint: RootView.Tab.workout.tint)
            }
            NavigationLink {
                WeightSettingsView()
            } label: {
                row("Weight", symbol: RootView.Tab.weight.symbol, tint: RootView.Tab.weight.tint)
            }
            NavigationLink {
                WaterSettingsView(store: water)
            } label: {
                row("Water", symbol: RootView.Tab.water.symbol, tint: RootView.Tab.water.tint)
            }
            NavigationLink {
                IntakeSettingsView(store: intake)
            } label: {
                row("Food", symbol: RootView.Tab.food.symbol, tint: RootView.Tab.food.tint)
            }
            Button {
                plates = PlateStore(defaultUnit: unitSystem)
            } label: {
                HStack {
                    row("Plates", symbol: "dumbbell.fill", tint: RootView.Tab.workout.tint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } header: {
            Text("Screens")
        }
    }

    private func row(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 26)
            Text(title)
                .foregroundStyle(Color.primary)
        }
    }

    #if os(iOS)
    /// What Senku writes to Apple Health. One switch per kind of data, each
    /// asking for its own permission the first time it is turned on.
    private var healthSection: some View {
        Section {
            if health.isAvailable {
                ForEach(HealthKind.allCases) { kind in
                    Toggle(isOn: Binding(
                        get: { health.settings.isOn(kind) },
                        set: { on in Task { await health.set(kind, on: on) } }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: Self.symbol(kind))
                                .foregroundStyle(Self.tint(kind))
                                .frame(width: 26)
                            Text(kind.title)
                        }
                    }
                    // Each in its own screen's colour. Left alone they take
                    // More's slate, and an "on" switch in grey reads as off.
                    .tint(Self.tint(kind))
                }
            } else {
                Text("Apple Health is not available on this device.")
                    .foregroundStyle(.secondary)
            }

            if let problem = health.problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(Senku.Palette.warning)
            }
        } header: {
            Text("Apple Health")
        }
    }

    private static func symbol(_ kind: HealthKind) -> String {
        switch kind {
        case .water: RootView.Tab.water.symbol
        case .food: RootView.Tab.food.symbol
        case .body: RootView.Tab.weight.symbol
        case .workouts: RootView.Tab.workout.symbol
        }
    }

    private static func tint(_ kind: HealthKind) -> Color {
        switch kind {
        case .water: RootView.Tab.water.tint
        case .food: RootView.Tab.food.tint
        case .body: RootView.Tab.weight.tint
        case .workouts: RootView.Tab.workout.tint
        }
    }
    #endif
}
#endif
