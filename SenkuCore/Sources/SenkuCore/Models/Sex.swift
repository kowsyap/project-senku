import Foundation

/// Biological sex, used only as an input to metabolic formulas.
///
/// The published BMR equations (Mifflin-St Jeor, Harris-Benedict) were derived
/// with a binary sex term, so that is what this models. It is a calculation
/// input, not an identity setting.
public enum Sex: String, Codable, Hashable, Sendable, CaseIterable {
    case male
    case female

    /// Deurenberg body-fat estimation uses 1 for male, 0 for female.
    var deurenbergFactor: Double {
        switch self {
        case .male: 1
        case .female: 0
        }
    }

    /// Lowest daily intake considered safe without medical supervision.
    var safeMinimumCalories: Double {
        switch self {
        case .male: 1500
        case .female: 1200
        }
    }
}
