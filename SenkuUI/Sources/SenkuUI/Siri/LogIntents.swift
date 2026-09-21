import Foundation
import SenkuCore

#if os(iOS)
import AppIntents
import WidgetKit

/// Logging by voice, for the times both hands are busy.
///
/// The counterpart to `LogWaterIntent`, which the water widget already uses.
/// These exist because protein is the figure most often known without the rest
/// of the label — a shake, a tin of tuna — and saying "log forty grams of
/// protein" mid-set is faster than anything involving the screen.
///
/// ## Three things every write from an intent has to do
///
/// Add it, tell the widgets, tell the watch. The last is the one that is easy
/// to forget: nothing on the wrist knows about a figure typed here unless the
/// phone publishes it, and a watch quietly a meal behind is worse than a watch
/// that never showed food at all.

@available(iOS 17.0, *)
public struct LogProteinIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log protein"
    public static let description = IntentDescription("Adds protein to today's total.")
    public static let openAppWhenRun = false

    /// Deliberately left unset by the empty initialiser.
    ///
    /// Assigning a default here is what made "log protein in Senku" silently
    /// record thirty grams: a parameter that already has a value is a question
    /// already answered, so nothing was asked and nothing was listened for.
    /// Unset, it is resolved — either from the number you said in the sentence,
    /// or by `requestValueDialog` asking for it.
    @Parameter(
        title: "Grams",
        controlStyle: .field,
        inclusiveRange: (1, 500),
        requestValueDialog: "How many grams of protein?"
    )
    public var grams: Double

    public init() {}
    public init(grams: Double) { self.grams = grams }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = IntakeStore()
        guard store.addProtein(grams) else {
            return .result(dialog: "That is not an amount I can log.")
        }

        Self.publish()

        guard let day = store.day(profile: ProfileStore().profile) else {
            return .result(dialog: "Logged.")
        }
        return .result(dialog: IntentDialog(stringLiteral: "Logged. " + SpokenSummary.protein(day)))
    }
}

@available(iOS 17.0, *)
public struct LogCaloriesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log calories"
    public static let description = IntentDescription("Adds calories to today's total.")
    public static let openAppWhenRun = false

    @Parameter(
        title: "Calories",
        controlStyle: .field,
        inclusiveRange: (1, 5000),
        requestValueDialog: "How many calories?"
    )
    public var calories: Double

    public init() {}
    public init(calories: Double) { self.calories = calories }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = IntakeStore()
        guard store.addCalories(calories) else {
            return .result(dialog: "That is not an amount I can log.")
        }

        Self.publish()

        guard let day = store.day(profile: ProfileStore().profile) else {
            return .result(dialog: "Logged.")
        }
        return .result(dialog: IntentDialog(stringLiteral: "Logged. " + SpokenSummary.intake(day)))
    }
}

@available(iOS 17.0, *)
extension AppIntent {
    /// Everything that has to hear about a write made from outside the app.
    @MainActor
    static func publish() {
        WidgetCenter.shared.reloadAllTimelines()
        PhoneSync.publish()
    }
}
#endif
