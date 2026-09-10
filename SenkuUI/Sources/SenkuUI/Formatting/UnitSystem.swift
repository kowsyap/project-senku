import Foundation
import SenkuCore

/// Which units the user types and reads.
///
/// This is strictly a presentation concern. `SenkuCore` only ever sees
/// kilograms and centimetres, so no calculation has to ask what the user picked.
public enum UnitSystem: String, Codable, CaseIterable, Identifiable, Sendable {
    case metric
    case imperial

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }

    public var massLabel: String {
        switch self {
        case .metric: "kg"
        case .imperial: "lb"
        }
    }

    public var volumeLabel: String {
        switch self {
        case .metric: "ml"
        case .imperial: "fl oz"
        }
    }
}

public enum Convert {
    public static let poundsPerKilogram = 2.204_622_62
    public static let centimetresPerInch = 2.54
    public static let millilitresPerFluidOunce = 29.5735

    public static func kilograms(fromPounds pounds: Double) -> Double {
        pounds / poundsPerKilogram
    }

    public static func pounds(fromKilograms kilograms: Double) -> Double {
        kilograms * poundsPerKilogram
    }

    public static func centimetres(feet: Int, inches: Double) -> Double {
        (Double(feet) * 12 + inches) * centimetresPerInch
    }

    /// Splits a height in centimetres into whole feet and remaining inches,
    /// rolling 12 inches up into a foot so `5' 12"` can never be displayed.
    public static func feetAndInches(fromCentimetres centimetres: Double) -> (feet: Int, inches: Double) {
        let totalInches = centimetres / centimetresPerInch
        var feet = Int(totalInches / 12)
        var inches = (totalInches - Double(feet) * 12).rounded()
        if inches >= 12 {
            feet += 1
            inches -= 12
        }
        return (feet, inches)
    }

    public static func fluidOunces(fromMillilitres millilitres: Double) -> Double {
        millilitres / millilitresPerFluidOunce
    }
}
