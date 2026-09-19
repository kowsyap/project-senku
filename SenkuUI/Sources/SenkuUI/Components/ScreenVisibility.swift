#if !os(watchOS)
import SwiftUI

private struct SenkuScreenVisibleKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether this screen is the one on display.
    ///
    /// Every page of the phone's shell stays mounted so that leaving a tab and
    /// coming back is a return rather than a fresh start — which means a hidden
    /// screen's `task` runs anyway. Harmless for most of them, and not harmless
    /// at all for the rest timer: it asks for notification permission as it
    /// appears, so the app was asking at launch, from a screen nobody had
    /// opened, about alerts for a timer nobody had started.
    ///
    /// Screens that do something on appearing read this and wait their turn.
    /// Anything presented on its own — a sheet, a pushed page — gets the
    /// default of `true`, because being presented is being visible.
    public var senkuScreenIsVisible: Bool {
        get { self[SenkuScreenVisibleKey.self] }
        set { self[SenkuScreenVisibleKey.self] = newValue }
    }
}
#endif
