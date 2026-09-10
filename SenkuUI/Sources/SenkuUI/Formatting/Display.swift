import Foundation
import SenkuCore

/// Formatting helpers shared by every screen.
public enum Display {
    public static func calories(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    public static func grams(_ value: Double) -> String {
        "\(Int(value.rounded())) g"
    }

    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    public static func signedCalories(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    public static func mass(_ kilograms: Double, in system: UnitSystem, decimals: Int = 1) -> String {
        let value = system == .metric ? kilograms : Convert.pounds(fromKilograms: kilograms)
        return String(format: "%.\(decimals)f %@", value, system.massLabel)
    }

    /// A signed rate of change, used for weekly weight projections.
    public static func massDelta(_ kilograms: Double, in system: UnitSystem) -> String {
        let value = system == .metric ? kilograms : Convert.pounds(fromKilograms: kilograms)
        return String(format: "%+.2f %@", value, system.massLabel)
    }

    public static func height(_ centimetres: Double, in system: UnitSystem) -> String {
        switch system {
        case .metric:
            return String(format: "%.0f cm", centimetres)
        case .imperial:
            let split = Convert.feetAndInches(fromCentimetres: centimetres)
            return "\(split.feet)′ \(Int(split.inches))″"
        }
    }

    public static func volume(_ millilitres: Double, in system: UnitSystem) -> String {
        switch system {
        case .metric:
            return "\(Int(millilitres.rounded())) ml"
        case .imperial:
            return String(format: "%.0f fl oz", Convert.fluidOunces(fromMillilitres: millilitres))
        }
    }

    public static func range(_ range: ClosedRange<Double>, in system: UnitSystem) -> String {
        let low = system == .metric ? range.lowerBound : Convert.pounds(fromKilograms: range.lowerBound)
        let high = system == .metric ? range.upperBound : Convert.pounds(fromKilograms: range.upperBound)
        return String(format: "%.0f–%.0f %@", low, high, system.massLabel)
    }

    /// "about 10 weeks" / "about 3 months", or nil when the goal is unreachable.
    public static func duration(weeks: Double?) -> String? {
        guard let weeks, weeks.isFinite, weeks > 0 else { return nil }
        if weeks < 1.5 { return "about a week" }
        if weeks < 9 { return "about \(Int(weeks.rounded())) weeks" }
        let months = weeks / 4.345
        if months < 1.5 { return "about a month" }
        if months < 18 { return "about \(Int(months.rounded())) months" }
        return "over a year"
    }
}
