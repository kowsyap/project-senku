import Foundation
import SenkuCore

/// How a due item's money and dates read.
public enum DueFormat {
    /// In the device's own currency: the app has no idea which card is in
    /// which currency, and the phone's region is the best guess there is.
    public static func amount(_ item: DueItem) -> String? {
        guard let amount = item.amount, amount > 0 else { return nil }
        return money(amount)
    }

    public static func money(_ amount: Double) -> String {
        let code = Locale.current.currency?.identifier ?? "USD"
        return amount.formatted(.currency(code: code).precision(.fractionLength(0...2)))
    }

    /// "Mon 5 Oct", with the year only when it is not this one.
    public static func date(_ date: Date, now: Date = .now) -> String {
        let sameYear = Calendar.current.isDate(date, equalTo: now, toGranularity: .year)
        return sameYear
            ? date.formatted(.dateTime.weekday(.abbreviated).day().month())
            : date.formatted(.dateTime.day().month().year())
    }
}
