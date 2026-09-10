import Foundation

/// Multiplier applied to BMR to estimate total daily energy expenditure.
public enum ActivityLevel: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case sedentary
    case light
    case moderate
    case active
    case athlete

    public var id: String { rawValue }

    public var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .athlete: 1.9
        }
    }

    public var title: String {
        switch self {
        case .sedentary: "Sedentary"
        case .light: "Lightly active"
        case .moderate: "Moderately active"
        case .active: "Very active"
        case .athlete: "Athlete"
        }
    }

    public var detail: String {
        switch self {
        case .sedentary: "Desk job, little or no exercise"
        case .light: "Light exercise 1–3 days a week"
        case .moderate: "Moderate exercise 3–5 days a week"
        case .active: "Hard exercise 6–7 days a week"
        case .athlete: "Physical job, or training twice a day"
        }
    }
}
