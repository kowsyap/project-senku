import Foundation
import Observation
import SenkuCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The owner's saved profile.
///
/// Backed by `UserDefaults` and JSON rather than SwiftData: the profile is a
/// single small value, and this keeps the package free of a model container so
/// it works identically on watchOS and in previews. When history and CloudKit
/// sync arrive, this is the seam to swap.
@Observable
public final class ProfileStore {
    public struct Profile: Codable, Hashable, Sendable {
        /// Optional, and decoded as nil when absent, so a profile saved before
        /// there was a name to give still reads back.
        public var name: String?

        public var metrics: BodyMetrics
        public var activityLevel: ActivityLevel
        public var goal: Goal
        public var formula: BMRFormula
        public var unitSystem: UnitSystem

        /// The weight being worked towards, if one was named.
        public var goalWeightKG: Double?

        /// Maintenance as measured from what you ate against what the scale
        /// did, once you have accepted it — see ``AdaptiveMaintenance``. Nil
        /// means the plan is using the formula, which is where everyone starts.
        ///
        /// Optional, so a profile saved before this existed still decodes.
        public var measuredMaintenanceCalories: Double?

        public var updatedAt: Date

        public init(
            name: String? = nil,
            metrics: BodyMetrics,
            activityLevel: ActivityLevel,
            goal: Goal,
            formula: BMRFormula,
            unitSystem: UnitSystem,
            goalWeightKG: Double? = nil,
            measuredMaintenanceCalories: Double? = nil,
            updatedAt: Date = .now
        ) {
            self.name = name
            self.metrics = metrics
            self.activityLevel = activityLevel
            self.goal = goal
            self.formula = formula
            self.unitSystem = unitSystem
            self.goalWeightKG = goalWeightKG
            self.measuredMaintenanceCalories = measuredMaintenanceCalories
            self.updatedAt = updatedAt
        }

        public var plan: NutritionPlan {
            NutritionPlan.make(
                for: metrics,
                activityLevel: activityLevel,
                goal: goal,
                formula: formula,
                measuredMaintenance: measuredMaintenanceCalories
            )
        }

        /// How long the current plan would take to reach `goalWeightKG`, when
        /// there is a target and the plan is actually moving towards it.
        public var weeksToGoalWeight: Double? {
            guard let goalWeightKG else { return nil }
            return plan.projectedWeeksTo(targetWeightKG: goalWeightKG)
        }
    }

    /// Shared with `SenkuStorage.migrateIfNeeded`, which has to know the key
    /// before any store exists to ask.
    static let storageKey = "senku.profile.v1"

    private let defaults: UserDefaults
    public private(set) var profile: Profile?

    /// Defaults to the App Group container so the widget sees the same profile.
    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.profile = Self.load(from: defaults)
    }

    public var hasProfile: Bool { profile != nil }

    /// - Parameter broadcast: whether to publish to the watch. False only when
    ///   the save *came* from the watch link, which would otherwise echo
    ///   straight back to the sender.
    public func save(_ profile: Profile, broadcast: Bool = true) {
        // Remembered outside the profile as well, so the screens that exist
        // without one still show the right unit. See `UnitPreference`.
        UnitPreference.current = profile.unitSystem

        var stamped = profile
        stamped.updatedAt = .now
        self.profile = stamped

        guard let data = try? JSONEncoder().encode(stamped) else { return }
        defaults.set(data, forKey: Self.storageKey)
        reloadWidgets()

        if broadcast { publish(stamped) }
    }

    /// Takes a profile that arrived from the other device, as it stands.
    ///
    /// Not `save`: the timestamp is the sender's, and re-stamping it here would
    /// make every device think it had the newest copy.
    public func apply(_ profile: Profile) {
        self.profile = profile
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.storageKey)
        }
        reloadWidgets()
    }

    public func clear(broadcast: Bool = true) {
        profile = nil
        defaults.removeObject(forKey: Self.storageKey)
        reloadWidgets()

        if broadcast { publish(nil) }
    }

    private func publish(_ profile: Profile?) {
        #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(watchOS)
        ProfileSync.shared.send(profile)
        #endif
    }

    /// The targets widget's timeline never expires on its own, because a plan
    /// only changes when the profile does. This is that change.
    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private static func load(from defaults: UserDefaults) -> Profile? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        // A profile that no longer decodes is dropped rather than crashing the
        // app: it is a convenience cache, not a source of truth worth dying for.
        return try? JSONDecoder().decode(Profile.self, from: data)
    }
}

extension PlanDraft {
    /// Seeds a draft from a saved profile.
    public convenience init(profile: ProfileStore.Profile) {
        self.init(
            name: profile.name ?? "",
            unitSystem: profile.unitSystem,
            sex: profile.metrics.sex,
            age: profile.metrics.age,
            heightCM: profile.metrics.heightCM,
            weightKG: profile.metrics.weightKG,
            usesMeasuredBodyFat: profile.metrics.bodyFatPercentage != nil,
            bodyFatPercentage: profile.metrics.bodyFatPercentage ?? 20,
            activityLevel: profile.activityLevel,
            goal: profile.goal,
            formula: profile.formula,
            goalWeightKG: profile.goalWeightKG
        )
    }

    /// A snapshot of the draft, or nil while the inputs are not yet valid.
    public var profileSnapshot: ProfileStore.Profile? {
        guard let metrics else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return ProfileStore.Profile(
            name: trimmed.isEmpty ? nil : trimmed,
            metrics: metrics,
            activityLevel: activityLevel,
            goal: goal,
            formula: formula,
            unitSystem: unitSystem,
            goalWeightKG: goalWeightKG
        )
    }
}
