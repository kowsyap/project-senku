import Foundation

/// Something a cardio machine can tell you, other than the time.
///
/// A string wrapper for the same reason ``WorkoutGroup`` is one: the list lives
/// in the catalogue as data, a machine nobody anticipated can be described
/// without a Swift change, and an unfamiliar name in the JSON must not fail the
/// decode of everything else.
public struct CardioMetric: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public var id: String { rawValue }

    public static let speed = CardioMetric("speed")
    public static let incline = CardioMetric("incline")
    public static let distance = CardioMetric("distance")
    public static let resistance = CardioMetric("resistance")
    public static let level = CardioMetric("level")
    public static let split = CardioMetric("split")
    public static let floors = CardioMetric("floors")
    public static let laps = CardioMetric("laps")
    public static let rounds = CardioMetric("rounds")

    /// How it is shown, and how many decimals it deserves.
    ///
    /// Distances and speeds are read off a display to one decimal; a count of
    /// rounds or floors is a whole number and a ".0" on it is noise.
    public var decimals: Int {
        switch self {
        case .floors, .laps, .rounds, .level, .resistance: 0
        default: 1
        }
    }

    public var title: String {
        switch self {
        case .speed: "Max speed"
        case .incline: "Max incline"
        case .distance: "Distance"
        case .resistance: "Resistance"
        case .level: "Level"
        case .split: "Split"
        case .floors: "Floors"
        case .laps: "Laps"
        case .rounds: "Rounds"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// The unit's short form, which depends on what the user measures in.
    public func unit(metric: Bool) -> String {
        switch self {
        case .speed: metric ? "km/h" : "mph"
        case .incline: "%"
        case .distance: metric ? "km" : "mi"
        case .split: "/500m"
        default: ""
        }
    }
}

/// A cardio session: how long, and the two or three numbers off the machine.
///
/// ## Why this is not a set
///
/// A ``LoggedSet`` is weight and reps, and neither means anything on a
/// treadmill. Forcing cardio through it would have produced entries of 0 kg ×
/// 0 reps with the real figures nowhere, and a PR page confidently reporting
/// that your best run was zero.
///
/// ## Why totals rather than intervals
///
/// A ladder of seven blocks — five minutes at 3.0, two at 5.0 on an incline,
/// and so on — is how the session is *performed*, and it is a poor thing to
/// type in afterwards: twenty-one numbers, every time, most of them the same as
/// last time. What is worth keeping is the shape of the whole: how long you
/// were on it, and how hard it got. So the session records totals, and the
/// ladder itself belongs where it is decided rather than where it is recorded.
public struct CardioEffort: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    /// Total time on the machine.
    public var seconds: TimeInterval
    /// Keyed by ``CardioMetric`` raw value, and holding only what was entered:
    /// a blank field is an absent key, not a zero, so "I did not look at the
    /// distance" never becomes "I covered no distance".
    public var values: [String: Double]
    public var completedAt: Date

    public init(
        id: UUID = UUID(),
        seconds: TimeInterval,
        values: [String: Double] = [:],
        completedAt: Date = .now
    ) throws {
        guard seconds > 0, seconds <= 24 * 60 * 60 else {
            throw ValidationError.restDurationOutOfRange(seconds)
        }
        self.id = id
        self.seconds = seconds
        self.values = values.filter { $0.value.isFinite }
        self.completedAt = completedAt
    }

    public func value(_ metric: CardioMetric) -> Double? {
        values[metric.rawValue]
    }

    public var minutes: Double { seconds / 60 }
}
