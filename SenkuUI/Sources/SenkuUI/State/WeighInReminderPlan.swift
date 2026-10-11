import Foundation

/// Which mornings the weigh-in reminder rings on — see `WeightReminder`.
///
/// Apart from the scheduler so it can be tested on the host, where there is no
/// notification centre to schedule with.
enum WeighInReminderPlan {
    /// The moments to remind: `hour` o'clock on each of the next `count` days
    /// still to come, leaving out any day that already has a weigh-in.
    ///
    /// The horizon is the next `count` days, not the next `count` reminders: a
    /// morning skipped because you weighed in is not made up for at the end.
    static func mornings(
        from now: Date,
        weighedIn: [Date],
        hour: Int,
        count: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        let logged = Set(weighedIn.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        return (0..<count).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let moment = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                  moment > now,
                  !logged.contains(day)
            else { return nil }
            return moment
        }
    }
}
