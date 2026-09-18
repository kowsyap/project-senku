import Foundation

/// The most you have lifted on something.
///
/// ## Two kinds, never blended
///
/// A *logged* record is derived from a set you actually recorded; a *manual*
/// one is a figure you typed in, perhaps from a training diary or a gym you
/// used before Senku existed. Both are kept, the better of the two is shown,
/// and the row says which it is — the same rule the app applies to a measured
/// body fat against an estimated one. Quietly merging them would make the one
/// number people care about the one number the app is vaguest about.
public struct PersonalRecord: Hashable, Codable, Sendable, Identifiable {
    public enum Source: Hashable, Codable, Sendable {
        /// Computed from a recorded set, which is the id kept here so the set
        /// can be found again — and so deleting the set can be reasoned about.
        case logged(setID: UUID)
        /// Asserted by the user.
        case manual

        public var isLogged: Bool {
            if case .logged = self { return true }
            return false
        }
    }

    public let id: UUID
    public let exerciseID: String
    public let weightKG: Double
    public let reps: Int
    public let date: Date
    public let source: Source

    /// Set instead of ``reps`` for a hold. See ``LoggedSet/seconds``.
    public var seconds: TimeInterval?

    public var isTimed: Bool { seconds != nil }

    public init(
        id: UUID = UUID(),
        exerciseID: String,
        weightKG: Double,
        reps: Int = 0,
        seconds: TimeInterval? = nil,
        date: Date = .now,
        source: Source = .manual
    ) throws {
        // Zero is a real lift: a pull-up is bodyweight and nothing else, and
        // "added weight" is the only figure worth recording for it. What it
        // means on screen depends on the exercise's equipment, which is the
        // view's business rather than the record's.
        guard weightKG >= 0, weightKG <= 1000 else {
            throw ValidationError.liftedWeightOutOfRange(weightKG)
        }
        if let seconds, seconds <= 0 || seconds > 60 * 60 {
            throw ValidationError.restDurationOutOfRange(seconds)
        }
        if seconds == nil {
            guard (1...100).contains(reps) else {
                throw ValidationError.repsOutOfRange(reps)
            }
        }
        self.id = id
        self.exerciseID = exerciseID
        self.weightKG = weightKG
        self.reps = reps
        self.seconds = seconds
        self.date = date
        self.source = source
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        exerciseID = try container.decode(String.self, forKey: .exerciseID)
        weightKG = try container.decode(Double.self, forKey: .weightKG)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        seconds = try container.decodeIfPresent(TimeInterval.self, forKey: .seconds)
        date = try container.decode(Date.self, forKey: .date)
        source = try container.decode(Source.self, forKey: .source)
    }

    /// Whether this record carries no external load — a bodyweight set.
    public var isBodyweightOnly: Bool { weightKG == 0 }

    /// Estimated one-rep max, by **Epley**: `w × (1 + reps/30)`.
    ///
    /// Named on screen wherever it is shown, because it is an estimate with a
    /// formula behind it and not a lift that happened. Epley is the common
    /// choice and is reasonable up to about ten reps; past that every formula
    /// in the literature starts guessing, which is why ``isReliableEstimate``
    /// exists rather than a silent extrapolation.
    /// Nil for a hold, where a rep-count formula has nothing to work with.
    public var estimatedOneRepMax: Double? {
        guard !isTimed else { return nil }
        return reps == 1 ? weightKG : weightKG * (1 + Double(reps) / 30)
    }

    /// Whether the estimate is worth trusting. A set of twenty tells you about
    /// endurance, not about a single.
    public var isReliableEstimate: Bool { !isTimed && reps <= 10 }
}

/// Every record for one exercise, and what the headline should be.
public struct ExerciseRecords: Hashable, Sendable, Identifiable {
    public let exerciseID: String
    /// Newest first.
    public let records: [PersonalRecord]

    public var id: String { exerciseID }

    public init(exerciseID: String, records: [PersonalRecord]) {
        self.exerciseID = exerciseID
        self.records = records.sorted { $0.date > $1.date }
    }

    /// The heaviest weight moved, at any rep count.
    ///
    /// Kept separate from the estimated max because they answer different
    /// questions — "what is the biggest number I have had on the bar" and "what
    /// could I probably do for one" — and because collapsing them into one
    /// figure would let a set of ten light reps outrank an actual heavy single.
    public var heaviest: PersonalRecord? {
        // Weight first, then reps as the tie-break: 100×5 beats 100×3, because
        // the same bar for longer is the better lift. The sign of that second
        // term is easy to get backwards — it was, until a test said so.
        records.max { lhs, rhs in
            (lhs.weightKG, Double(lhs.reps)) < (rhs.weightKG, Double(rhs.reps))
        }
    }

    /// The longest hold, for an exercise measured in seconds.
    ///
    /// The counterpart of ``heaviest`` for planks and wall sits, and the figure
    /// the record page leads with for them. Added weight breaks ties: a minute
    /// with a plate beats a minute without.
    public var longestHold: PersonalRecord? {
        records.filter(\.isTimed).max { lhs, rhs in
            (lhs.seconds ?? 0, lhs.weightKG) < (rhs.seconds ?? 0, rhs.weightKG)
        }
    }

    /// Whether this exercise is recorded in seconds rather than reps.
    public var isTimed: Bool { records.contains(where: \.isTimed) }

    /// The figure to lead with: the longest hold, or the heaviest set.
    public var best: PersonalRecord? { isTimed ? longestHold : heaviest }

    /// The best estimated single, from sets in the range where the estimate
    /// means something.
    public var bestEstimated: PersonalRecord? {
        records
            .filter(\.isReliableEstimate)
            .max { ($0.estimatedOneRepMax ?? 0) < ($1.estimatedOneRepMax ?? 0) }
    }

    public var mostRecent: PersonalRecord? { records.first }

    /// Whether this lift has gone unbeaten for a while. Useful, and honest
    /// about what it means: a lift can be stale because you stopped doing it,
    /// not because you stopped progressing.
    public func isStale(at now: Date = .now, after days: TimeInterval = 60) -> Bool {
        guard let mostRecent else { return false }
        return now.timeIntervalSince(mostRecent.date) > days * 86_400
    }
}

/// Every personal record, by exercise.
///
/// A plain value computed from the stored list, so nothing derived is persisted
/// and the rules below are the only place they are decided.
public struct RecordBook: Sendable {
    public let records: [PersonalRecord]

    public init(_ records: [PersonalRecord]) {
        self.records = records
    }

    public var exerciseIDs: [String] {
        Array(Set(records.map(\.exerciseID)))
    }

    public func records(for exerciseID: String) -> ExerciseRecords {
        ExerciseRecords(
            exerciseID: exerciseID,
            records: records.filter { $0.exerciseID == exerciseID }
        )
    }

    /// One entry per exercise, best-lifted first.
    public var byExercise: [ExerciseRecords] {
        exerciseIDs
            .map { records(for: $0) }
            .sorted { ($0.heaviest?.weightKG ?? 0) > ($1.heaviest?.weightKG ?? 0) }
    }

    /// The record already standing for this exact lift, if there is one.
    ///
    /// Same weight, same reps, on the same exercise. Recording it twice adds no
    /// information — the first time already said you can do it — and leaves two
    /// identical rows whose only difference is a date, which reads as a logging
    /// mistake rather than a history.
    ///
    /// Compared with a tolerance because the weight has been through pounds and
    /// back on an imperial device, and 100.00000000000001 kg is the same lift.
    public func existingRecord(
        exerciseID: String,
        weightKG: Double,
        reps: Int,
        seconds: TimeInterval? = nil
    ) -> PersonalRecord? {
        records(for: exerciseID).records.first { record in
            guard abs(record.weightKG - weightKG) < 0.01 else { return false }
            if let seconds { return record.seconds.map { abs($0 - seconds) < 0.5 } ?? false }
            return record.seconds == nil && record.reps == reps
        }
    }

    /// Whether a set would beat what is already recorded.
    ///
    /// Beating means either more weight than has ever been on the bar, or a
    /// better estimated single — a set of 100×5 is a record over 100×3 even
    /// though the weight is unchanged, and the app would be wrong to ignore it.
    public func wouldBeRecord(
        exerciseID: String,
        weightKG: Double,
        reps: Int,
        seconds: TimeInterval? = nil
    ) -> Bool {
        let existing = records(for: exerciseID)

        // A hold is ranked by the clock: longer wins, and the same time with
        // more weight on your back wins. There is no estimated single to
        // compare, which is the whole reason this path exists.
        if let seconds {
            guard let longest = existing.longestHold else { return true }
            if seconds > (longest.seconds ?? 0) + 0.5 { return true }
            return abs(seconds - (longest.seconds ?? 0)) < 0.5 && weightKG > longest.weightKG
        }

        guard let heaviest = existing.heaviest else { return true }

        if weightKG > heaviest.weightKG { return true }

        guard reps <= 10 else { return false }
        let candidate = reps == 1 ? weightKG : weightKG * (1 + Double(reps) / 30)
        let best = existing.bestEstimated?.estimatedOneRepMax ?? 0
        return candidate > best
    }
}
