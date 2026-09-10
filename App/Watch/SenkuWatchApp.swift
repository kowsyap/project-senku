import SwiftUI
import SenkuCore
import SenkuUI

/// The watchOS entry point.
///
/// The watch reads the profile; it does not edit it. Until WatchConnectivity
/// lands in Phase 3 this reads the watch's own storage, so it stays empty until
/// the phone pushes a profile across.
@main
struct SenkuWatchApp: App {
    @State private var store = ProfileStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
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
    }
}
