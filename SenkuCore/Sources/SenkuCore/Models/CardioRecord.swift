import Foundation

/// A cardio session worth keeping: the time, and what the machine said.
///
/// ## What counts as a record here
///
/// For a lift it is the heaviest bar. For a machine there is no single answer —
/// longer is not always better, and a hard twenty minutes beats a gentle
/// forty — so this keeps **time** as the headline and every other figure
/// alongside it, and calls a session a record when it is the longest yet *or*
/// beats the best on any figure that exercise reports. A faster top speed at
/// the same duration is a real improvement and the page would be lying to omit
/// it.
///
/// Deliberately separate from ``PersonalRecord`` rather than bolted onto it.
/// That type is weight and reps all the way down — its Epley estimate, its
/// "heaviest", its bodyweight rule — and widening it to mean "or else a
/// duration and a bag of numbers" would make every one of those properties
/// conditional on which kind it was.
public struct CardioRecord: Identifiable, Codable, Hashable, Sendable {
    public enum Source: Codable, Hashable, Sendable {
        case logged(sessionID: UUID)
        case manual
    }

    public let id: UUID
    public let exerciseID: String
    public var seconds: TimeInterval
    /// Keyed by ``CardioMetric`` raw value, holding only what was entered.
    public var values: [String: Double]
    public var date: Date
    public var source: Source

    public init(
        id: UUID = UUID(),
        exerciseID: String,
        seconds: TimeInterval,
        values: [String: Double] = [:],
        date: Date = .now,
        source: Source = .manual
    ) throws {
        guard seconds > 0, seconds <= 24 * 60 * 60 else {
            throw ValidationError.restDurationOutOfRange(seconds)
        }
        self.id = id
        self.exerciseID = exerciseID
        self.seconds = seconds
        self.values = values.filter { $0.value.isFinite }
        self.date = date
        self.source = source
    }

    public init(_ effort: CardioEffort, exerciseID: String, sessionID: UUID) throws {
        try self.init(
            id: UUID(),
            exerciseID: exerciseID,
            seconds: effort.seconds,
            values: effort.values,
            date: effort.completedAt,
            source: .logged(sessionID: sessionID)
        )
    }

    public var minutes: Double { seconds / 60 }

    public func value(_ metric: CardioMetric) -> Double? { values[metric.rawValue] }
}

/// Everything recorded for one cardio exercise.
public struct CardioExerciseRecords: Identifiable, Hashable, Sendable {
    public var id: String { exerciseID }

    public let exerciseID: String
    /// Newest first.
    public let records: [CardioRecord]

    public init(exerciseID: String, records: [CardioRecord]) {
        self.exerciseID = exerciseID
        self.records = records.sorted { $0.date > $1.date }
    }

    /// The longest session, which is what the list shows.
    public var longest: CardioRecord? {
        records.max { $0.seconds < $1.seconds }
    }

    public var mostRecent: CardioRecord? { records.first }

    /// The best figure for one metric, across every session.
    public func best(_ metric: CardioMetric) -> Double? {
        records.compactMap { $0.value(metric) }.max()
    }
}

/// The cardio half of the record book.
public struct CardioBook: Sendable {
    public let records: [CardioRecord]

    public init(_ records: [CardioRecord]) {
        self.records = records
    }

    public var exerciseIDs: Set<String> { Set(records.map(\.exerciseID)) }

    public func records(for exerciseID: String) -> CardioExerciseRecords {
        CardioExerciseRecords(
            exerciseID: exerciseID,
            records: records.filter { $0.exerciseID == exerciseID }
        )
    }

    public var byExercise: [CardioExerciseRecords] {
        exerciseIDs
            .map { records(for: $0) }
            .sorted { ($0.mostRecent?.date ?? .distantPast) > ($1.mostRecent?.date ?? .distantPast) }
    }

    /// Whether a session beats what is already there — on time, or on any
    /// figure that exercise reports.
    public func wouldBeRecord(
        exerciseID: String,
        seconds: TimeInterval,
        values: [String: Double]
    ) -> Bool {
        let existing = records(for: exerciseID)
        guard let longest = existing.longest else { return true }

        if seconds > longest.seconds + 0.5 { return true }

        for (key, value) in values {
            let best = existing.best(CardioMetric(key))
            if best == nil || value > (best ?? 0) + 0.001 { return true }
        }
        return false
    }
}
