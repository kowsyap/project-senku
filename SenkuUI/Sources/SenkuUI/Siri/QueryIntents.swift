import Foundation
import SenkuCore

#if os(iOS)
import AppIntents

/// The intents that answer a question rather than do something.
///
/// Every other intent in Senku performs an action — log a drink, start a rest —
/// and returns nothing worth hearing. These return a `ProvidesDialog` result,
/// which is the string Siri speaks.
///
/// ## Why each one builds its own stores
///
/// An intent runs outside any screen, often with the app not running at all, so
/// there is nothing in memory to read. Constructing the store *is* the read: it
/// loads from the App Group, which is where the widgets and the watch write
/// too. The same rule the widgets follow, for the same reason.
///
/// The wording lives in `SpokenSummary`, away from here, so it can be tested
/// without a phone to talk to.

@available(iOS 17.0, *)
public struct WeightQueryIntent: AppIntent {
    public static let title: LocalizedStringResource = "Check my weight"
    public static let description = IntentDescription(
        "Reads back your latest weigh-in and the weekly rate from the trend."
    )
    public static let openAppWhenRun = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let profile = ProfileStore().profile
        let series = WeightLogStore().series
        let system = profile?.unitSystem ?? UnitPreference.current

        return .result(dialog: IntentDialog(stringLiteral: SpokenSummary.weight(series, in: system)))
    }
}

@available(iOS 17.0, *)
public struct WaterQueryIntent: AppIntent {
    public static let title: LocalizedStringResource = "Check my water"
    public static let description = IntentDescription(
        "Reads back how much water you have drunk today against your goal."
    )
    public static let openAppWhenRun = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // The goal is resolved, never stored — it depends on the profile and on
        // whether today was a training day, so the workout store comes too.
        let day = WaterStore().day(profile: ProfileStore().profile, workouts: WorkoutStore())

        return .result(dialog: IntentDialog(stringLiteral: SpokenSummary.water(day)))
    }
}

@available(iOS 17.0, *)
public struct IntakeQueryIntent: AppIntent {
    public static let title: LocalizedStringResource = "Check my food"
    public static let description = IntentDescription(
        "Reads back today's protein and calories against your targets."
    )
    public static let openAppWhenRun = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Nil when there is no plan yet: targets come from the profile, and
        // there is nothing honest to compare today against without one.
        guard let day = IntakeStore().day(profile: ProfileStore().profile) else {
            return .result(dialog: Self.noPlan)
        }

        return .result(dialog: IntentDialog(stringLiteral: SpokenSummary.intake(day)))
    }
}

@available(iOS 17.0, *)
public struct ProteinQueryIntent: AppIntent {
    public static let title: LocalizedStringResource = "Check my protein"
    public static let description = IntentDescription(
        "Reads back today's protein against your target."
    )
    public static let openAppWhenRun = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let day = IntakeStore().day(profile: ProfileStore().profile) else {
            return .result(dialog: Self.noPlan)
        }

        return .result(dialog: IntentDialog(stringLiteral: SpokenSummary.protein(day)))
    }
}
/// Said when the profile has no plan in it, so there are no targets to answer
/// against. Not an error: a first-run app has nothing to say yet, and saying
/// "zero of zero grams" would be worse than admitting it.
@available(iOS 17.0, *)
extension AppIntent {
    static var noPlan: IntentDialog {
        "Set up your plan in Senku first, and I can answer that."
    }
}
#endif
