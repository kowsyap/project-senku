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
    let unitSystem: UnitSystem

    /// Opened fresh for the rack editor; the plate calculator reads the
    /// saved rack again when it next appears.
    @State private var plates: PlateStore?
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

            #if os(iOS)
            healthSection
            #endif

            screensSection

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
