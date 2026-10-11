import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// When one day ends and the next begins, for everything you log.
///
/// Midnight by default, or one, two or three in the morning: a glass of water at half past
/// one after a late night belongs to the day you were living, not to a
/// tomorrow that has not started for you. It decides which day a drink, a
/// meal, a weigh-in, a creatine tick or a workout counts towards — and so
/// today's totals, the streaks and the averages built on them.
///
/// It does not move anything that is set by the clock on the wall: reminders
/// ring at their hour, a bill is due on its date.
///
/// ## How
///
/// A calendar whose time zone is shifted back by the boundary's hours, used
/// wherever a log is put on a day. "The start of the day" in that calendar is
/// three o'clock local, and everything that already groups by a calendar —
/// totals, streaks, the week's chart — moves with it, without each of them
/// learning about boundaries. The shift is the offset in force now, so on the
/// night the clocks change a reading near the boundary can fall an hour
/// differently; on every other night it is exact.
public enum DayBoundary {
    public static let storageKey = "senku.dayBoundary.v1"

    /// Midnight to three. Later than three would start taking the early
    /// riser's first glass of the morning.
    public static let choices = [0, 1, 2, 3]

    public static var hour: Int {
        get {
            let stored = SenkuStorage.shared.integer(forKey: storageKey)
            return choices.contains(stored) ? stored : 0
        }
        set { SenkuStorage.shared.set(newValue, forKey: storageKey) }
    }

    /// The calendar a day starts in at `hour`.
    public static func calendar(hour: Int, base: Calendar = .current, at now: Date = .now) -> Calendar {
        guard hour != 0 else { return base }
        var shifted = base
        let offset = base.timeZone.secondsFromGMT(for: now) - hour * 3600
        shifted.timeZone = TimeZone(secondsFromGMT: offset) ?? base.timeZone
        return shifted
    }

    /// A stored day — the start of a day, saved under whichever boundary was
    /// set at the time — as the day it means in `calendar`.
    ///
    /// Read by its midday, which every boundary puts in the same day. Read by
    /// its own instant, a creatine tick saved at midnight would land on the
    /// day before under a three o'clock boundary, and switching the setting
    /// would quietly move every tick back by one.
    public static func day(of stamp: Date, in calendar: Calendar) -> Date {
        calendar.startOfDay(for: stamp.addingTimeInterval(12 * 3600))
    }

    /// The widgets reset their totals at the boundary, so a change redraws them.
    public static func refreshWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public static func title(_ hour: Int) -> String {
        hour == 0 ? "Midnight" : "\(hour) am"
    }
}

extension Calendar {
    /// The calendar a log is put on a day in — see ``DayBoundary``.
    public static var logging: Calendar {
        DayBoundary.calendar(hour: DayBoundary.hour)
    }
}
