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

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    RestTimerView()
                        .navigationTitle("Rest")
                }

                NavigationStack {
                    planTab
                        .navigationTitle("Plan")
                }
            }
            .tabViewStyle(.verticalPage)
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
