import Foundation

/// Basal metabolic rate: the energy cost of simply staying alive for a day.
public enum BMRFormula: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    /// Picks Katch-McArdle when body fat is known, Mifflin-St Jeor otherwise.
    case automatic

    /// The modern default. Most accurate for the general population.
    case mifflinStJeor

    /// Lean-mass based, so it beats the others for lean and muscular people —
    /// but only if body fat is actually measured, not estimated.
    case katchMcArdle

    /// The 1984 revision. Included for comparison; tends to run slightly high.
    case harrisBenedict

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: "Automatic"
        case .mifflinStJeor: "Mifflin-St Jeor"
        case .katchMcArdle: "Katch-McArdle"
        case .harrisBenedict: "Harris-Benedict"
        }
    }

    /// The formula actually applied for a given person.
    ///
    /// Katch-McArdle is only chosen when body fat was *measured*; falling back
    /// to it on a Deurenberg estimate would compound one estimate onto another.
    public func resolved(for metrics: BodyMetrics) -> BMRFormula {
        guard self == .automatic else { return self }
        return metrics.bodyFatPercentage == nil ? .mifflinStJeor : .katchMcArdle
    }

    public func basalMetabolicRate(for metrics: BodyMetrics) -> Double {
        let weight = metrics.weightKG
        let height = metrics.heightCM
        let age = Double(metrics.age)

        switch resolved(for: metrics) {
        case .automatic:
            // Unreachable: `resolved` never returns `.automatic`.
            return BMRFormula.mifflinStJeor.basalMetabolicRate(for: metrics)

        case .mifflinStJeor:
            let base = (10 * weight) + (6.25 * height) - (5 * age)
            return metrics.sex == .male ? base + 5 : base - 161

        case .katchMcArdle:
            return 370 + (21.6 * metrics.leanBodyMassKG)

        case .harrisBenedict:
            switch metrics.sex {
            case .male:
                return 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age)
            case .female:
                return 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age)
            }
        }
    }
}
