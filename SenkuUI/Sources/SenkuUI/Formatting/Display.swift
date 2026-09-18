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

    /// Grams with a decimal only when there is one: "30 g", but "1.3 g".
    ///
    /// Food is the one place in the app where a tenth of a gram is real — an
    /// egg is 6.3 g of protein and a banana 1.3 g, and rounding those to whole
    /// numbers loses a fifth of the banana before anything is even added up.
    /// Lifts and body weights have no such problem, which is why this is not
    /// the default everywhere.
    public static func gramsValue(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? "\(Int(rounded))"
            : String(format: "%.1f", rounded)
    }

    public static func tidyGrams(_ value: Double) -> String { "\(gramsValue(value)) g" }

    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    public static func signedCalories(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    /// "60s" or "1:30" — a held set.
    public static func hold(_ seconds: TimeInterval) -> String {
        seconds < 60
            ? "\(Int(seconds.rounded()))s"
            : clock(seconds)
    }

    /// One set, however it was measured: "60 kg×8", "60s", "+10 kg · 60s".
    public static func set(
        weightKG: Double,
        reps: Int,
        seconds: TimeInterval?,
        in system: UnitSystem
    ) -> String {
        guard let seconds else {
            return "\(mass(weightKG, in: system, decimals: 0))×\(reps)"
        }
        guard weightKG > 0 else { return hold(seconds) }
        return "+\(mass(weightKG, in: system, decimals: 0)) · \(hold(seconds))"
    }

    /// "22 min · 7.0 km/h · 12%" — a cardio session in one line.
    ///
    /// Time always, then whatever that machine reported, in the order the
    /// exercise lists them. Nothing is padded out with zeroes for the figures
    /// that were left blank.
    public static func cardio(
        _ effort: CardioEffort,
        for exercise: Exercise?,
        in system: UnitSystem
    ) -> String {
        var parts = ["\(Int((effort.seconds / 60).rounded())) min"]

        for metric in exercise?.cardioMetrics ?? [] {
            guard let value = effort.value(metric) else { continue }
            let unit = metric.unit(metric: system == .metric)
            let number = value.formatted(.number.precision(.fractionLength(0...metric.decimals)))
            parts.append(unit.isEmpty ? "\(number) \(metric.title.lowercased())" : "\(number) \(unit)")
        }
        return parts.joined(separator: " · ")
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

    /// Water, in millilitres, whatever the unit system says.
    ///
    /// The one measure the app keeps metric on purpose. Nobody fills a bottle
    /// in fluid ounces — bottles are sold in millilitres and litres the world
    /// over — and "66 fl oz" is a number you would have to convert before it
    /// meant anything at the tap.
    public static func millilitres(_ value: Double) -> String {
        "\(Int(value.rounded())) ml"
    }

    /// A weight with the decimal only when there is one.
    ///
    /// `mass` always prints a tenth, which is right for a body weight — 78.4
    /// and 78.0 are different readings and the trailing zero says the scale was
    /// read to that precision. A lift is not like that: the bar is 100 kg, not
    /// "100.0 kg", and a column of false decimals is harder to scan for no
    /// added truth. Plates that genuinely land on a half still show it.
    public static func tidyMass(_ kilograms: Double, in system: UnitSystem) -> String {
        let value = system == .metric ? kilograms : Convert.pounds(fromKilograms: kilograms)
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? "\(Int(rounded)) \(system.massLabel)"
            : String(format: "%.1f %@", rounded, system.massLabel)
    }

    /// Grams where a quarter of a small widget is all the room there is.
    ///
    /// The space before the unit is what does not fit — four columns of "157 g"
    /// at a legible size do not go into 130 points, and eliding a number is
    /// never the right trade.
    public static func compactGrams(_ value: Double) -> String {
        "\(Int(value.rounded()))g"
    }

    /// Volume for a space that has no room for "2800 ml".
    ///
    /// Litres past a litre, which is how anyone says it out loud anyway, and
    /// short enough to sit under a widget's macro column without eliding to
    /// "2800…" — an ellipsis where a number should be is worse than a rounder
    /// number.
    public static func compactVolume(_ millilitres: Double, in system: UnitSystem) -> String {
        switch system {
        case .metric:
            return millilitres >= 1000
                ? String(format: "%.1f L", millilitres / 1000)
                : "\(Int(millilitres.rounded())) ml"
        case .imperial:
            return String(format: "%.0f oz", Convert.fluidOunces(fromMillilitres: millilitres))
        }
    }

    public static func range(_ range: ClosedRange<Double>, in system: UnitSystem) -> String {
        let low = system == .metric ? range.lowerBound : Convert.pounds(fromKilograms: range.lowerBound)
        let high = system == .metric ? range.upperBound : Convert.pounds(fromKilograms: range.upperBound)
        return String(format: "%.0f–%.0f %@", low, high, system.massLabel)
    }


    /// A countdown as `m:ss`, or `h:mm:ss` past an hour.
    ///
    /// Rounds *up*, so a timer set for 90 seconds reads "1:30" the instant it
    /// starts rather than flicking to "1:29" before the user has looked at it,
    /// and only shows "0:00" when the time is genuinely gone.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded(.up))
        let (hours, minutes, secs) = (total / 3600, (total % 3600) / 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// How long a finished timer has been sitting unacknowledged, as "+0:40".
    public static func overrun(_ seconds: TimeInterval) -> String {
        "+" + clock(seconds)
    }

    /// Spoken form for VoiceOver, which reads "1:30" as a date otherwise.
    public static func spokenClock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded(.up))
        let (minutes, secs) = (total / 60, total % 60)
        switch (minutes, secs) {
        case (0, let s): return "\(s) second\(s == 1 ? "" : "s")"
        case (let m, 0): return "\(m) minute\(m == 1 ? "" : "s")"
        case (let m, let s): return "\(m) minute\(m == 1 ? "" : "s") \(s) second\(s == 1 ? "" : "s")"
        }
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
