import SwiftUI
import SenkuCore
import SenkuUI

/// The watchOS entry point.
///
/// Two tabs, and the order is deliberate: Rest comes first because it is the
/// only reason to raise your wrist mid-set. The plan is the reference you check
/// occasionally; the timer is the thing you came for.
///
/// The watch reads the profile; it does not edit it. Until WatchConnectivity
/// lands in Phase 3 this reads the watch's own storage, so the plan tab stays
/// empty until the phone pushes a profile across. The rest timer needs no
/// profile, which is why it is useful on day one.
@main
struct SenkuWatchApp: App {
    @State private var store = ProfileStore()
    @State private var selection = Tab.rest

    /// What the phone last said about weight. Held here rather than persisted:
    /// the phone owns the log, and a stale copy on the wrist is worth less than
    /// an empty one that fills in the moment the two are together.
    @State private var weight = WeightSummary()

    private enum Tab: Hashable { case rest, plan, weight }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selection) {
                NavigationStack {
                    RestTimerView()
                        .navigationTitle("Rest")
                }
                .tag(Tab.rest)

                NavigationStack {
                    planTab
                        .navigationTitle("Plan")
                }
                .tag(Tab.plan)

                NavigationStack {
                    WatchWeightView(summary: weight) { weightKG in
                        guard let weighIn = try? WeighIn(date: .now, weightKG: weightKG) else { return }
                        // Sent, not stored. The phone keeps the history; the
                        // watch is a way in to it.
                        ProfileSync.shared.send(weighIn: weighIn)
                        weight.lastWeightKG = weightKG
                        weight.lastLoggedAt = .now
                    }
                    .navigationTitle("Weight")
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
