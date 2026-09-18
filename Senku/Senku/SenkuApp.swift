import SwiftUI
import SenkuUI

/// The iPhone, iPad and Mac (Catalyst) entry point.
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
        #if os(iOS) && !targetEnvironment(macCatalyst)
        MainActor.assumeIsolated { PhoneSync.start() }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 760, height: 940)
        #endif
    }
}
