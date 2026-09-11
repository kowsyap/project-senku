import WidgetKit
import SwiftUI

@main
struct SenkuWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestWidget()
        RestLiveActivity()
        if #available(iOS 18.0, *) {
            RestControl()
        }
    }
}
