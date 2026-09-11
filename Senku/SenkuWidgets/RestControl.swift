import WidgetKit
import SwiftUI
import AppIntents
import SenkuCore
import SenkuUI

/// A Control Center button that starts a rest.
///
/// This is the shortest path the feature has: swipe down, tap, the rest is
/// running — no unlocking, no finding the app, no choosing an interval. It
/// reuses the last interval rather than asking, because mid-set is the wrong
/// moment for a question.
@available(iOS 18.0, *)
struct RestControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "SenkuStartRest") {
            ControlWidgetButton(action: StartRestIntent()) {
                Label("Start rest", systemImage: "timer")
            }
        }
        .displayName("Start rest")
        .description("Start Senku's rest timer at your last interval.")
    }
}
