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
        public static let ringWidth: CGFloat = 18
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
