import Foundation
import Observation
import SenkuCore

/// The owner's saved profile.
///
/// Backed by `UserDefaults` and JSON rather than SwiftData: the profile is a
/// single small value, and this keeps the package free of a model container so
/// it works identically on watchOS and in previews. When history and CloudKit
/// sync arrive, this is the seam to swap.
@Observable
public final class ProfileStore {
    public struct Profile: Codable, Hashable, Sendable {
        public var metrics: BodyMetrics
        public var activityLevel: ActivityLevel
        public var goal: Goal
        public var formula: BMRFormula
        public var unitSystem: UnitSystem
        public var updatedAt: Date

        public init(
            metrics: BodyMetrics,
            activityLevel: ActivityLevel,
            goal: Goal,
            formula: BMRFormula,
            unitSystem: UnitSystem,
            updatedAt: Date = .now
        ) {
            self.metrics = metrics
            self.activityLevel = activityLevel
            self.goal = goal
            self.formula = formula
            self.unitSystem = unitSystem
            self.updatedAt = updatedAt
        }

        public var plan: NutritionPlan {
            NutritionPlan.make(
                for: metrics,
                activityLevel: activityLevel,
                goal: goal,
                formula: formula
            )
        }
    }

    private static let storageKey = "senku.profile.v1"

    private let defaults: UserDefaults
    public private(set) var profile: Profile?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.profile = Self.load(from: defaults)
    }

    public var hasProfile: Bool { profile != nil }

    public func save(_ profile: Profile) {
        var stamped = profile
        stamped.updatedAt = .now
        self.profile = stamped

        guard let data = try? JSONEncoder().encode(stamped) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    public func clear() {
        profile = nil
        defaults.removeObject(forKey: Self.storageKey)
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
            unitSystem: profile.unitSystem,
            sex: profile.metrics.sex,
            age: profile.metrics.age,
            heightCM: profile.metrics.heightCM,
            weightKG: profile.metrics.weightKG,
            usesMeasuredBodyFat: profile.metrics.bodyFatPercentage != nil,
            bodyFatPercentage: profile.metrics.bodyFatPercentage ?? 20,
            activityLevel: profile.activityLevel,
            goal: profile.goal,
            formula: profile.formula
        )
    }

    /// A snapshot of the draft, or nil while the inputs are not yet valid.
    public var profileSnapshot: ProfileStore.Profile? {
        guard let metrics else { return nil }
        return ProfileStore.Profile(
            metrics: metrics,
            activityLevel: activityLevel,
            goal: goal,
            formula: formula,
            unitSystem: unitSystem
        )
    }
}
