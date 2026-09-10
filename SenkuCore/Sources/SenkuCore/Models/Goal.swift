import Foundation

/// The direction and aggressiveness of a body-composition goal.
///
/// Adjustments are percentages of maintenance rather than flat calorie numbers,
/// so a 60 kg and a 110 kg person both get a proportionate change.
public enum Goal: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case aggressiveCut
    case moderateCut
    case mildCut
    case maintain
    case leanBulk
    case moderateBulk
    case aggressiveBulk

    public var id: String { rawValue }

    /// Fraction of maintenance calories to eat.
    public var calorieMultiplier: Double {
        switch self {
        case .aggressiveCut: 0.75
        case .moderateCut: 0.80
        case .mildCut: 0.90
        case .maintain: 1.00
        case .leanBulk: 1.10
        case .moderateBulk: 1.15
        case .aggressiveBulk: 1.20
        }
    }

    public var isCut: Bool { calorieMultiplier < 1 }
    public var isBulk: Bool { calorieMultiplier > 1 }

    public var title: String {
        switch self {
        case .aggressiveCut: "Aggressive cut"
        case .moderateCut: "Moderate cut"
        case .mildCut: "Mild cut"
        case .maintain: "Maintain"
        case .leanBulk: "Lean bulk"
        case .moderateBulk: "Moderate bulk"
        case .aggressiveBulk: "Aggressive bulk"
        }
    }

    /// Expected weekly bodyweight change, as a fraction of bodyweight.
    public var weeklyBodyweightChangeFraction: Double {
        switch self {
        case .aggressiveCut: -0.010
        case .moderateCut: -0.0075
        case .mildCut: -0.004
        case .maintain: 0
        case .leanBulk: 0.002
        case .moderateBulk: 0.004
        case .aggressiveBulk: 0.006
        }
    }

    public var detail: String {
        switch self {
        case .aggressiveCut: "Fastest fat loss. Harder to keep muscle and adherence."
        case .moderateCut: "The standard cut. Good balance of speed and retention."
        case .mildCut: "Slow, very sustainable. Best if you are already lean."
        case .maintain: "Hold weight steady. Good for recomp and skill work."
        case .leanBulk: "Minimal fat gain. Best for those already near their limit."
        case .moderateBulk: "The standard bulk. Steady gain with some fat."
        case .aggressiveBulk: "Fast gain, more fat. Mainly for hard gainers."
        }
    }
}
