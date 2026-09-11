import Foundation

/// The rest intervals offered as one-tap choices.
///
/// Five covers almost every set worth timing. The short end is for accessory
/// work where the muscle recovers before the nervous system does; the long end
/// is for heavy compounds where it is the other way round.
public enum RestPreset: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case sixtySeconds
    case ninetySeconds
    case twoMinutes
    case threeMinutes
    case fiveMinutes

    public var id: String { rawValue }

    public var duration: TimeInterval {
        switch self {
        case .sixtySeconds: 60
        case .ninetySeconds: 90
        case .twoMinutes: 120
        case .threeMinutes: 180
        case .fiveMinutes: 300
        }
    }

    public var title: String {
        switch self {
        case .sixtySeconds: "1:00"
        case .ninetySeconds: "1:30"
        case .twoMinutes: "2:00"
        case .threeMinutes: "3:00"
        case .fiveMinutes: "5:00"
        }
    }

    public var detail: String {
        switch self {
        case .sixtySeconds: "Isolation and accessory work"
        case .ninetySeconds: "Hypertrophy sets, 8–12 reps"
        case .twoMinutes: "Moderate compounds"
        case .threeMinutes: "Heavy compounds, 3–6 reps"
        case .fiveMinutes: "Near-maximal singles and doubles"
        }
    }

    /// The preset matching a duration exactly, if there is one. Lets a restored
    /// timer light up the right button instead of always reading as custom.
    public static func matching(_ duration: TimeInterval) -> RestPreset? {
        allCases.first { $0.duration == duration }
    }
}
