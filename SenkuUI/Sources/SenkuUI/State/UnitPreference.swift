import Foundation

/// What to show weights in, when there is no profile to ask.
///
/// The unit belongs to the profile — it is part of how someone describes
/// themselves — and for anyone who has filled one in, that is the answer. But
/// the PR page, the weight log and the workout screens all exist before a
/// profile does, and after a hard reset they exist again: falling back to
/// kilograms there means an imperial user sees every figure they just imported
/// in the wrong unit, with nowhere obvious to change it.
///
/// So the last unit chosen is remembered separately, and used as the fallback.
/// Saving a profile updates it; an imported file may set it directly, which is
/// what lets a backup restore a device that has no profile yet.
public enum UnitPreference {
    static let storageKey = "senku.unitSystem.v1"

    public static var current: UnitSystem {
        get {
            let raw = SenkuStorage.shared.string(forKey: storageKey) ?? ""
            return UnitSystem(rawValue: raw) ?? .metric
        }
        set {
            SenkuStorage.shared.set(newValue.rawValue, forKey: storageKey)
        }
    }
}
