import WidgetKit
import SwiftUI

@main
struct SenkuWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestWidget()
        // Back after the App Group turned out to be available on a free
        // account: with no shared container this widget could never read the
        // profile, so it was removed rather than left showing an empty state
        // forever. It can see the profile now.
        TargetsWidget()
        RestLiveActivity()
        if #available(iOS 18.0, *) {
            RestControl()
        }
    }
}
