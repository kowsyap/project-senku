import Foundation
#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

/// Haptic feedback, where the platform has any.
///
/// The rest timer is the one place in this app where feedback is the point
/// rather than a nicety: the whole value of the timer on a watch is that you
/// feel it finish without looking at it. Mac and Mac Catalyst have nothing to
/// play, so these are no-ops there.
public enum Feedback {
    /// The buzzer. Called exactly once per rest, on the running→finished edge.
    public static func restFinished() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }

    /// A light tick for starting, pausing and preset taps.
    public static func control() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
}
