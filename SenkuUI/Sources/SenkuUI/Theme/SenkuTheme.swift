import SwiftUI
import SenkuCore

/// Every colour and metric the UI uses, in one place.
///
/// Colours are defined as literals rather than asset catalogue entries so the
/// package stays self-contained and usable from any target without copying
/// assets around.
public enum Senku {
    public enum Palette {
        /// Protein — the macro the app pushes hardest on a cut.
        public static let protein = Color(red: 0.35, green: 0.55, blue: 0.95)
        /// The blue the "Me" tab's mark is filled with. Brighter and cooler
        /// than `protein`, so the face does not read as another blue glyph.
        public static let saiyanBlue = Color(red: 0.18, green: 0.68, blue: 0.96)
        /// Carbohydrate.
        public static let carbs = Color(red: 0.98, green: 0.68, blue: 0.24)
        /// Fat.
        public static let fat = Color(red: 0.42, green: 0.78, blue: 0.55)

        public static let warning = Color(red: 0.90, green: 0.35, blue: 0.32)
        public static let caution = Color(red: 0.95, green: 0.65, blue: 0.20)
        public static let info = Color(red: 0.45, green: 0.60, blue: 0.72)

        public static let deficit = Color(red: 0.35, green: 0.62, blue: 0.92)
        public static let surplus = Color(red: 0.42, green: 0.75, blue: 0.50)
    }

    public enum Metrics {
        public static let cardCorner: CGFloat = 16
        public static let cardPadding: CGFloat = 16
        public static let stackSpacing: CGFloat = 14

        #if os(watchOS)
        // A 40 mm screen is about 160 pt across. At phone proportions the ring
        // fills it entirely and pushes Start below the fold, which is the one
        // control you need without scrolling between sets.
        public static let ringWidth: CGFloat = 11
        public static let timerRingMaxWidth: CGFloat = 148
        public static let timerDigitSize: CGFloat = 42
        public static let presetColumns = 2
        #else
        public static let ringWidth: CGFloat = 18
        public static let timerRingMaxWidth: CGFloat = 260
        public static let timerDigitSize: CGFloat = 56
        public static let presetColumns = 3
        #endif
    }
}

extension RestPreset {
    /// The colour this interval wears everywhere: the phone's Rest screen, the
    /// Home Screen widget, the watch and its complication.
    ///
    /// Warm to cool as the rest gets longer, so the right button is found by
    /// colour at arm's length rather than by reading near-identical numbers
    /// mid-set. Defined once — a colour that means "one minute" in one place
    /// and something else in another is worse than no colour at all.
    public var tint: Color {
        switch self {
        case .sixtySeconds: .red
        case .ninetySeconds: Color(red: 0.98, green: 0.45, blue: 0.25)
        case .twoMinutes: .orange
        case .threeMinutes: .yellow
        case .fiveMinutes: Senku.Palette.fat
        }
    }

    /// The intervals offered on a full screen: one, two, three and five
    /// minutes. Ninety seconds is left out of the row on purpose — it is a
    /// keystroke away on the custom stepper, and five buttons across a phone
    /// are narrower than four without being more useful.
    public static let oneTapStarts: [RestPreset] = [
        .sixtySeconds, .twoMinutes, .threeMinutes, .fiveMinutes,
    ]

    /// The three that fit a watch face or a small widget.
    public static let quickStarts: [RestPreset] = [
        .sixtySeconds, .twoMinutes, .threeMinutes,
    ]

    /// The interval in whole minutes, for a face with room for one number.
    public var minutes: Int { Int(duration / 60) }
}

extension WorkoutGroup {
    /// A glyph for the group, so six headings can be told apart by shape before
    /// they are read.
    ///
    /// SF Symbols has no chest, lat or delt icon, and dressing six rows in
    /// near-identical athletic figures would be decoration pretending to be
    /// information. These are picked for the movement each group is trained by
    /// — a press, a row, an overhead raise, a curl, an extension, a step — and
    /// carry a colour each, which is what actually does the telling apart at a
    /// glance.
    public var symbol: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rower"
        case .shoulder: "figure.arms.open"
        case .bicep: "dumbbell.fill"
        case .tricep: "figure.cooldown"
        case .legs: "figure.stair.stepper"
        case .abs: "figure.core.training"
        case .cardio: "heart.fill"
        default: "figure.strengthtraining.functional"
        }
    }

    public var tint: Color {
        switch self {
        // Coral rather than the palette's red, which cardio now owns: two
        // groups in the same red is the one confusion a colour-coded list
        // cannot survive.
        case .chest: Color(red: 0.98, green: 0.51, blue: 0.35)
        case .back: Senku.Palette.protein
        case .shoulder: Senku.Palette.carbs
        case .bicep: Color(red: 0.62, green: 0.45, blue: 0.92)
        case .tricep: Color(red: 0.25, green: 0.72, blue: 0.75)
        case .legs: Senku.Palette.fat
        case .abs: Color(red: 0.95, green: 0.55, blue: 0.62)
        case .cardio: Color(red: 0.91, green: 0.19, blue: 0.24)
        default: Senku.Palette.info
        }
    }
}

extension Advisory.Severity {
    var tint: Color {
        switch self {
        case .warning: Senku.Palette.warning
        case .caution: Senku.Palette.caution
        case .info: Senku.Palette.info
        }
    }

    var symbol: String {
        switch self {
        case .warning: "exclamationmark.triangle.fill"
        case .caution: "exclamationmark.circle.fill"
        case .info: "info.circle.fill"
        }
    }
}
