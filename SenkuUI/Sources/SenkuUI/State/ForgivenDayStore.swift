import Foundation
import Observation
import SenkuCore

/// Days you have said you simply did not log, per habit.
///
/// ## What this is, and what it is not
///
/// It is not an edit. You cannot say "I drank 2 litres on Tuesday" after the
/// fact — that is a history that can be made to say anything, and a streak
/// built on one is worth nothing. What you can say is "Tuesday has no
/// information in it", which is a different claim and an honest one: the phone
/// was flat, you were on a plane, you forgot.
///
/// A forgiven day is stepped over by the streak rather than counted by it. The
/// run survives; the tally of days actually done does not go up. See
/// ``Streak/of(_:forgiven:on:calendar:)``.
@Observable
public final class ForgivenDayStore {
    static let storageKey = "senku.forgivenDays.v1"

    private let defaults: UserDefaults
    private let calendar: Calendar

    /// Keyed by the track's id — "water", "creatine", "protein", "calories" —
    /// so forgiving a day of one habit says nothing about the others. Missing
    /// your protein and drinking your water is an ordinary Tuesday.
    public private(set) var days: [String: Set<Date>] = [:]

    public init(defaults: UserDefaults = SenkuStorage.shared, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        reload()
    }

    public func reload() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let stored = try? JSONDecoder().decode([String: Set<Date>].self, from: data)
        else {
            days = [:]
            return
        }
        days = stored
    }

    public func days(for track: String) -> Set<Date> { days[track] ?? [] }

    public func isForgiven(_ date: Date, in track: String) -> Bool {
        days(for: track).contains(calendar.startOfDay(for: date))
    }

    /// Only a day that has finished. Today is still live — it can be logged —
    /// and tomorrow has not happened, so neither can be forgiven.
    public func canForgive(_ date: Date, on today: Date = .now) -> Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: today)
    }

    public func setForgiven(_ forgiven: Bool, on date: Date, in track: String) {
        guard canForgive(date) else { return }

        let day = calendar.startOfDay(for: date)
        var set = days[track] ?? []

        if forgiven {
            set.insert(day)
        } else {
            set.remove(day)
        }

        days[track] = set.isEmpty ? nil : set
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(days) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
