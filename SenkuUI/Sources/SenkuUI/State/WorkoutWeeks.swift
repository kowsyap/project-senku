import Foundation
import SenkuCore

/// One training week of logged workouts, Monday to Sunday, and what it added
/// up to.
public struct WorkoutWeek: Identifiable, Sendable {
    public let interval: DateInterval
    /// Newest first, as the history lists them.
    public let sessions: [WorkoutSession]

    public var id: Date { interval.start }

    public var totalSets: Int { sessions.reduce(0) { $0 + $1.totalSets } }
    public var volumeKG: Double { sessions.reduce(0) { $0 + $1.volumeKG } }
    public var cardioSeconds: TimeInterval { sessions.reduce(0) { $0 + $1.cardioSeconds } }

    /// Time trained, from each session's own clock. A session left open for
    /// under a minute is a mis-tap, not training, and adds nothing.
    public var trainedSeconds: TimeInterval {
        sessions.reduce(0) { total, session in
            guard let duration = session.duration, duration > 60 else { return total }
            return total + duration
        }
    }

    /// How many days of the week had a workout in them.
    public func trainingDays(calendar: Calendar = .logging) -> Int {
        Set(sessions.map { calendar.startOfDay(for: $0.date) }).count
    }

    /// The days of the week's plan that were trained.
    public var dayIDs: Set<UUID> { Set(sessions.map(\.dayID)) }

    /// Every group trained, in the order first met, oldest session first.
    public var groups: [WorkoutGroup] {
        var seen: Set<WorkoutGroup> = []
        return sessions.reversed().flatMap(\.groups).filter { seen.insert($0).inserted }
    }

    /// Every exercise performed in the week, once each.
    public var performedExerciseIDs: [String] {
        var seen: Set<String> = []
        return sessions.reversed().flatMap(\.performedExerciseIDs).filter { seen.insert($0).inserted }
    }

    /// Every set logged in the week — what a record has to point at to have
    /// been set in it.
    public var setIDs: Set<UUID> {
        Set(sessions.flatMap { $0.entries.flatMap { $0.sets.map(\.id) } })
    }

    /// How many of these records were set by a set logged in this week.
    public func recordsSet(in records: [PersonalRecord]) -> Int {
        PersonalRecord.count(setBy: setIDs, in: records)
    }
}

extension PersonalRecord {
    /// How many of these records came from one of these logged sets.
    static func count(setBy sets: Set<UUID>, in records: [PersonalRecord]) -> Int {
        records.filter {
            if case let .logged(setID) = $0.source { return sets.contains(setID) }
            return false
        }.count
    }
}

extension WorkoutSession {
    /// How many of these records were set in this session.
    func recordsSet(in records: [PersonalRecord]) -> Int {
        PersonalRecord.count(setBy: Set(entries.flatMap { $0.sets.map(\.id) }), in: records)
    }
}

/// The workout history, the way the history screen shows it.
///
/// Weeks as cards — except the week you are in, whose workouts are listed one
/// by one while it is still being trained. Once every day of the plan has been
/// done in it, it is a finished week like any other and becomes a card too.
public struct WorkoutHistoryLayout: Sendable {
    /// This week's workouts, newest first, while the week is still open.
    public let thisWeek: [WorkoutSession]
    /// Newest first: earlier weeks, and this one once it is complete.
    public let weeks: [WorkoutWeek]

    public static func make(
        history: [WorkoutSession],
        plan: TrainingPlan,
        now: Date = .now,
        calendar: Calendar = .logging
    ) -> WorkoutHistoryLayout {
        var buckets: [Date: (interval: DateInterval, sessions: [WorkoutSession])] = [:]
        for session in history {
            guard let week = WorkoutStore.week(containing: session.date, calendar: calendar) else { continue }
            buckets[week.start, default: (week, [])].sessions.append(session)
        }

        let current = WorkoutStore.week(containing: now, calendar: calendar)
        let planned = Set(plan.days.filter { !$0.isEmpty }.map(\.id))

        var thisWeek: [WorkoutSession] = []
        var weeks: [WorkoutWeek] = []

        for (start, bucket) in buckets.sorted(by: { $0.key > $1.key }) {
            let sessions = bucket.sessions.sorted { $0.date > $1.date }
            let week = WorkoutWeek(interval: bucket.interval, sessions: sessions)

            if start == current?.start {
                // Done when every planned day has been trained this week. A
                // week with no plan to finish stays open until it is over.
                let isComplete = !planned.isEmpty && planned.isSubset(of: week.dayIDs)
                if !isComplete {
                    thisWeek = sessions
                    continue
                }
            }
            weeks.append(week)
        }

        return WorkoutHistoryLayout(thisWeek: thisWeek, weeks: weeks)
    }
}
