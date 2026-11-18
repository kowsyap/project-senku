#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Colours, icons and words the money screens share.
enum MoneyStyle {
    /// Eight series colours in a fixed order, with their own steps for dark
    /// mode — checked for colour-blind separation as a set, so they are used
    /// in this order and never cycled. A ninth group is "Other".
    static let series: [Color] = [
        dynamic(0x2A78D6, 0x3987E5),  // blue
        dynamic(0xEB6834, 0xD95926),  // orange
        dynamic(0x1BAF7A, 0x199E70),  // aqua
        dynamic(0xEDA100, 0xC98500),  // yellow
        dynamic(0xE87BA4, 0xD55181),  // magenta
        dynamic(0x008300, 0x0CA30C),  // green
        dynamic(0x6250D6, 0x9085E9),  // violet
        dynamic(0xE34948, 0xE66767),  // red
    ]

    static let other = dynamic(0xA3A29C, 0x6C6B66)

    /// Colours for a chart's groups, in the order given; "Other" is grey.
    static func colors(for keys: [String]) -> [String: Color] {
        var map: [String: Color] = [:]
        var slot = 0
        for key in keys {
            if key == MoneyReport.other {
                map[key] = other
            } else {
                map[key] = series[min(slot, series.count - 1)]
                slot += 1
            }
        }
        return map
    }

    static func symbol(for category: String) -> String {
        switch category {
        case "Groceries": "cart.fill"
        case "Restaurants": "fork.knife"
        case "Coffee & Snacks": "cup.and.saucer.fill"
        case "Transport": "car.fill"
        case "Rent": "house.fill"
        case "Utilities": "bolt.fill"
        case "Subscriptions": "repeat"
        case "Shopping": "bag.fill"
        case "Electronics": "laptopcomputer"
        case "Snacks": "popcorn.fill"
        case "Health": "cross.case.fill"
        case "Fitness": "dumbbell.fill"
        case "Education": "graduationcap.fill"
        case "Entertainment": "film.fill"
        case "Personal Care": "scissors"
        case "Gifts": "gift.fill"
        case "Family": "figure.2.and.child.holdinghands"
        case "Loan / EMI": "building.columns.fill"
        case "Insurance": "shield.fill"
        case "Miscellaneous": "ellipsis.circle.fill"
        default: "tag.fill"
        }
    }

    /// "$1,477.43", or "$450" when whole — never "$3,629.6".
    static func money(_ amount: Double) -> String {
        let code = Locale.current.currency?.identifier ?? "USD"
        let cents = (amount * 100).rounded()
        let whole = cents.truncatingRemainder(dividingBy: 100) == 0
        return amount.formatted(.currency(code: code).precision(.fractionLength(whole ? 0 : 2)))
    }

    /// A share as a whole percentage, "<1" rather than a misleading 0.
    static func share(_ fraction: Double) -> String {
        let value = Int((fraction * 100).rounded())
        return value == 0 && fraction > 0 ? "<1" : "\(value)"
    }

    /// "Nov 2026", or "November 2026" written out.
    static func title(_ month: YearMonth, long: Bool = false) -> String {
        month.firstDay().formatted(.dateTime.month(long ? .wide : .abbreviated).year())
    }

    /// "+12%" or "−8%".
    static func percent(_ fraction: Double) -> String {
        let value = Int((fraction * 100).rounded())
        return value > 0 ? "+\(value)%" : value < 0 ? "−\(abs(value))%" : "0%"
    }

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        #if canImport(UIKit)
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
        #else
        Color(red: Double((light >> 16) & 0xFF) / 255, green: Double((light >> 8) & 0xFF) / 255, blue: Double(light & 0xFF) / 255)
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

extension MoneyStore.Kind {
    var title: String { self == .expenses ? "Expenses" : "Income" }
    var entryNoun: String { self == .expenses ? "spend" : "income" }
    var nameLabel: String { self == .expenses ? "Name" : "Source" }
    var groupTitle: String { self == .expenses ? "By category" : "By source" }
    var groupLabel: String { self == .expenses ? "Category" : "Source" }
    var totalLabel: String { self == .expenses ? "Spent" : "Earned" }
}
#endif
