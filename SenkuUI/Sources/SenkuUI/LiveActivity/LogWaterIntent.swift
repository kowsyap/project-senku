import Foundation
import SenkuCore

#if os(iOS) && !targetEnvironment(macCatalyst)
import AppIntents
import WidgetKit

/// Logs a drink from a widget button, without opening the app.
///
/// The same idea as the rest timer's `StopRestIntent`: the work is small, it
/// touches storage the widget can already see, and launching Senku to record a
/// glass of water would cost more than the glass did. `openAppWhenRun = false`
/// is what keeps the Home Screen where it is.
///
/// Reloading timelines at the end is not optional — the widget's own button has
/// just changed the number the widget is showing, and without the reload it
/// would go on showing the old one until the system next felt like refreshing.
@available(iOS 17.0, *)
public struct LogWaterIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log water"
    public static let description = IntentDescription("Adds a drink to today's total.")

    public static let openAppWhenRun = false

    @Parameter(title: "Millilitres")
    public var millilitres: Int

    public init() {
        self.millilitres = 250
    }

    public init(millilitres: Int) {
        self.millilitres = millilitres
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        let store = WaterStore()
        let container = store.settings.containers.first { Int($0.millilitres) == millilitres }

        store.add(millilitres: Double(millilitres), container: container)
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
#endif
