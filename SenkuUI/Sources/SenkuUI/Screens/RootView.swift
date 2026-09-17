#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The app's entry screen.
///
/// Three tabs. "Me" is a profile that persists and improves over time, while
/// "Quick calc" is for the friend who asks a question in the gym — no account,
/// no onboarding, nothing written down. The two audiences genuinely differ.
///
/// "Rest" sits alongside them rather than inside either, because it is the one
/// screen reached mid-set with a bar waiting: it has to be one tap from
/// anywhere, and it needs no profile to be useful.
///
/// ## Why a tab view and not a drawer
///
/// The destinations are a `sidebarAdaptable` `TabView`, which is the same
/// declaration rendered as a tab bar on iPhone and as a real sidebar on iPad
/// and Mac — and which lets the person using it reorder and pin what matters to
/// them as more sections arrive. A hand-built menu would trade the one-tap
/// guarantee above for a tap, a read and a second tap, and hide every new
/// feature behind a button until someone went looking for it.
public struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var store: ProfileStore
    @State private var weightLog = WeightLogStore()
    @State private var records = RecordStore()
    @State private var library = ExerciseLibrary()
    @State private var selection: Tab

    /// Reset when a profile is saved or cleared, so the calculator rebuilds its
    /// draft from the new state instead of holding a stale one.
    @State private var profileEditionID = UUID()

    enum Tab: String, Hashable {
        case me
        case quickCalc
        case rest
        case weight
        case records
    }

    public init(store: ProfileStore = ProfileStore()) {
        _store = State(initialValue: store)
        _selection = State(initialValue: store.hasProfile ? .me : .quickCalc)
    }

    public var body: some View {
        Group {
            if #available(iOS 18.0, macOS 15.0, *) {
                AdaptiveTabs(selection: $selection) {
                    meTab
                } quickCalc: {
                    quickCalcTab
                } rest: {
                    restTab
                } weight: {
                    weightTab
                } records: {
                    recordsTab
                }
            } else {
                legacyTabs
            }
        }
        .onOpenURL { url in
            if RestDeepLink.handle(url) != nil {
                selection = .rest
            }
        }
        .task {
            // The phone publishes the profile; the watch picks it up whenever
            // it next runs. Started here rather than in the app entry point so
            // that previews and tests, which build their own store, never open
            // a session at all.
            #if os(iOS) && !targetEnvironment(macCatalyst)
            ProfileSync.shared.start(applying: store)

            // A weigh-in typed on the watch lands here, in the log that owns
            // the history. The watch keeps none of its own.
            ProfileSync.shared.onWeighInReceived { weighIn in
                weightLog.add(weighIn)
                publishWeight()
            }

            publishWeight()
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            // Republished whenever the app comes forward, which is the cheapest
            // honest definition of "regularly": the phone is the source, and
            // the moment you have been looking at it is the moment its numbers
            // are most likely to have changed.
            #if os(iOS) && !targetEnvironment(macCatalyst)
            if phase == .active { publishWeight() }
            #endif
        }
        .onChange(of: weightLog.weighIns) { _, _ in publishWeight() }
        .onChange(of: profileEditionID) { _, _ in publishWeight() }
    }

    /// Sends the watch the two figures it shows. Cheap enough to call freely:
    /// an application context replaces the one before it, so calling this three
    /// times in a second costs one delivery.
    private func publishWeight() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        ProfileSync.shared.send(weight: WeightSummary(log: weightLog, profile: store.profile))
        #endif
    }

    // MARK: - The destinations

    private var meTab: some View {
        NavigationStack {
            profileTab
                .navigationTitle(store.hasProfile ? "My plan" : "Senku")
                .senkuWordmark()
        }
    }

    private var quickCalcTab: some View {
        NavigationStack {
            // Saving is offered whether or not a profile exists. It used
            // to be hidden once one did, on the theory that this tab was
            // then only for other people's numbers — which left someone who
            // had just worked out their own new numbers here with no way to
            // keep them.
            CalculatorView(
                draft: PlanDraft(),
                saveTitle: store.hasProfile ? "Update my profile" : "Save as my profile"
            ) { profile in
                store.save(profile)
                profileEditionID = UUID()
                selection = .me
            }
            .navigationTitle("Quick calc")
            .senkuWordmark()
        }
    }

    private var restTab: some View {
        NavigationStack {
            RestTimerView()
                .navigationTitle("Rest")
                .senkuWordmark()
        }
    }

    private var weightTab: some View {
        NavigationStack {
            WeightLogView(store: weightLog, profile: store.profile) { trend in
                // Adopting the trend edits the one field it measures and leaves
                // the rest of the profile alone.
                guard var updated = store.profile else { return }
                guard let metrics = try? BodyMetrics(
                    sex: updated.metrics.sex,
                    age: updated.metrics.age,
                    heightCM: updated.metrics.heightCM,
                    weightKG: trend,
                    bodyFatPercentage: updated.metrics.bodyFatPercentage
                ) else { return }

                updated.metrics = metrics
                store.save(updated)
                profileEditionID = UUID()
            }
            .navigationTitle("Weight")
            .senkuWordmark()
        }
    }

    private var recordsTab: some View {
        NavigationStack {
            RecordsView(
                store: records,
                library: library,
                unitSystem: store.profile?.unitSystem ?? .metric
            )
                .navigationTitle("PRs")
                .senkuWordmark()
        }
    }

    /// The pre-iOS 18 arrangement: a plain tab bar, no sidebar and no pinning.
    private var legacyTabs: some View {
        TabView(selection: $selection) {
            meTab
                .tabItem { Label("Me", systemImage: "person.fill") }
                .tag(Tab.me)

            quickCalcTab
                .tabItem { Label("Quick calc", systemImage: "function") }
                .tag(Tab.quickCalc)

            restTab
                .tabItem { Label("Rest", systemImage: "timer") }
                .tag(Tab.rest)

            weightTab
                .tabItem { Label("Weight", systemImage: "scalemass") }
                .tag(Tab.weight)

            recordsTab
                .tabItem { Label("PRs", systemImage: "trophy") }
                .tag(Tab.records)
        }
    }

    @ViewBuilder
    private var profileTab: some View {
        if let profile = store.profile {
            ProfileDashboardView(profile: profile) { updated in
                store.save(updated)
                profileEditionID = UUID()
            }
            .id(profileEditionID)
        } else {
            emptyProfile
        }
    }

    private var emptyProfile: some View {
        ContentUnavailableView {
            Label("No profile yet", systemImage: "person.crop.circle.dashed")
        } description: {
            Text("Work out your numbers in Quick calc, then save them here to keep them.")
        } actions: {
            Button("Open quick calc") {
                selection = .quickCalc
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

/// The tab view that grows into a sidebar.
///
/// Separate because its customization — the reordering and pinning, remembered
/// across launches — is an iOS 18 type, and a stored property cannot be marked
/// available only from a later system the way a view can.
@available(iOS 18.0, macOS 15.0, *)
private struct AdaptiveTabs<Me: View, QuickCalc: View, Rest: View, Weight: View, Records: View>: View {
    @Binding var selection: RootView.Tab

    @ViewBuilder var me: Me
    @ViewBuilder var quickCalc: QuickCalc
    @ViewBuilder var rest: Rest
    @ViewBuilder var weight: Weight
    @ViewBuilder var records: Records

    /// What the user has moved, pinned or hidden. Versioned, because a stored
    /// customization is keyed by the identifiers below: renaming one silently
    /// drops whatever they had arranged.
    @AppStorage("senku.tabs.v1") private var customization = TabViewCustomization()

    var body: some View {
        TabView(selection: $selection) {
            Tab("Me", systemImage: "person.fill", value: RootView.Tab.me) { me }
                .customizationID("senku.tab.me")

            Tab("Quick calc", systemImage: "function", value: RootView.Tab.quickCalc) { quickCalc }
                .customizationID("senku.tab.quickCalc")

            // Never hideable: this is the screen reached mid-set, and a rest
            // timer behind a customisation menu is a rest timer that is not
            // there when it is needed.
            Tab("Rest", systemImage: "timer", value: RootView.Tab.rest) { rest }
                .customizationID("senku.tab.rest")
                #if os(iOS)
                .customizationBehavior(.disabled, for: .sidebar, .tabBar)
                #endif

            Tab("Weight", systemImage: "scalemass", value: RootView.Tab.weight) { weight }
                .customizationID("senku.tab.weight")

            Tab("PRs", systemImage: "trophy", value: RootView.Tab.records) { records }
                .customizationID("senku.tab.records")
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($customization)
    }
}

#Preview("Root") {
    RootView(store: ProfileStore(defaults: UserDefaults(suiteName: "senku.preview")!))
}
#endif
