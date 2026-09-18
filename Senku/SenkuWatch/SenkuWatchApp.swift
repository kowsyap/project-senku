import SwiftUI
import SenkuCore
import SenkuUI

/// The watchOS entry point.
///
/// Three pages: the plan, the timer, the scale. Rest sits in the middle and is
/// what the app opens on — the page you came for is one you land on, not one
/// you scroll to, and being in the middle means either neighbour is a single
/// swipe away.
///
/// None of them carry a title. A page heading on a watch names what you are
/// already looking at and costs a fifth of the screen to do it — and with the
/// vertical page style, the dots at the edge already say where you are.
///
/// The watch reads the profile; it does not edit it. Until WatchConnectivity
/// lands in Phase 3 this reads the watch's own storage, so the plan tab stays
/// empty until the phone pushes a profile across. The rest timer needs no
/// profile, which is why it is useful on day one.
@main
struct SenkuWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var store = ProfileStore()
    @State private var selection = Tab.rest

    /// What the phone last said about weight. Held here rather than persisted:
    /// the phone owns the log, and a stale copy on the wrist is worth less than
    /// an empty one that fills in the moment the two are together.
    @State private var weight = WeightSummary()

    private enum Tab: Hashable { case rest, plan, weight }

    init() {
        // Before anything can schedule a rest. Without it the alert is
        // suppressed for arriving while the app is on screen — which, with the
        // runtime session holding the app in front, is every time.
        RestAlerts.installPresenter()
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selection) {
                NavigationStack {
                    planTab
                }
                .tag(Tab.plan)

                NavigationStack {
                    RestTimerView()
                }
                .tag(Tab.rest)

                NavigationStack {
                    WatchWeightView(summary: weight) { weightKG in
                        guard let weighIn = try? WeighIn(date: .now, weightKG: weightKG) else { return }
                        // Sent, not stored. The phone keeps the history; the
                        // watch is a way in to it.
                        ProfileSync.shared.send(weighIn: weighIn)
                        weight.lastWeightKG = weightKG
                        weight.lastLoggedAt = .now
                    }
                }
                .tag(Tab.weight)
            }
            .tabViewStyle(.verticalPage)
            .task {
                // Receives the phone's profile. The watch never publishes one:
                // it reads the profile, it does not edit it.
                ProfileSync.shared.start(applying: store)
                ProfileSync.shared.onWeightSummaryReceived { summary in
                    if let summary { weight = summary }
                }

                // And ask, rather than only wait. A profile edited on the phone
                // while this app was closed would otherwise arrive whenever the
                // system got round to it.
                ProfileSync.shared.requestRefresh()
            }
            .onChange(of: scenePhase) { _, phase in
                // Coming back to the app is the moment its numbers are most
                // likely to be out of date.
                if phase == .active { ProfileSync.shared.requestRefresh() }
            }
            .onChange(of: selection) { _, tab in
                // Opening the tab that shows the phone's numbers is the moment
                // to make sure they are the phone's current ones.
                if tab == .plan || tab == .weight {
                    ProfileSync.shared.requestRefresh()
                }
            }
            .onOpenURL { url in
                // A complication was pressed. The watch app owns the timer, the
                // haptic and the notification, so the rest is started here
                // rather than in the complication's own process — which cannot
                // do any of those three.
                if RestDeepLink.handle(url) != nil {
                    selection = .rest
                }
            }
        }
    }

    @ViewBuilder
    private var planTab: some View {
        if let profile = store.profile {
            WatchPlanView(plan: profile.plan, unitSystem: profile.unitSystem)
        } else {
            ContentUnavailableView(
                "No profile",
                systemImage: "iphone.gen3",
                description: Text("Set up your profile on iPhone first.")
            )
        }
    }
}
