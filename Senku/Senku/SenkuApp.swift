import SwiftUI
import SenkuUI

/// The iPhone and iPad entry point.
///
/// Deliberately thin. Everything of substance lives in the SenkuUI and
/// SenkuCore packages, which is what lets the same code serve every platform
/// and be built and tested without an Xcode project.
@main
struct SenkuApp: App {
    init() {
        RestAlerts.installPresenter()

        // Before any scene exists. The watch can wake this app in the
        // background, and everything it asks for has to work with no window —
        // see PhoneSync for the two days of stale figures that proved it.
        #if os(iOS)
        MainActor.assumeIsolated {
            PhoneSync.start()
            #if DEBUG
            SampleData.loadIfAsked()
            #endif
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
