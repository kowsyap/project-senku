import Foundation

/// One set, as performed.
///
/// Weight and reps only. RPE is in the requirements as a maybe and is not here:
/// a field nobody fills in is worse than no field, and it can be added without
/// touching anything that reads this — which is the test of whether leaving it
/// out was safe.
public struct LoggedSet: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var weightKG: Double
    public var reps: Int

    /// Set instead of ``reps`` for a hold — a plank, a wall sit.
    ///
    /// Kept as a separate field rather than by pressing seconds into `reps`,
    /// because every figure derived from reps would then be quietly wrong: a
    /// sixty-second plank would read as sixty repetitions and produce an
    /// estimated one-rep max three times bodyweight.
    public var seconds: TimeInterval?

    public var completedAt: Date

    public init(
        id: UUID = UUID(),
        weightKG: Double,
        reps: Int = 0,
        seconds: TimeInterval? = nil,
        completedAt: Date = .now
    ) throws {
        // Zero weight is a real set — press-ups, chin-ups, hanging leg raises —
        // and the same reasoning as `PersonalRecord`, which shares this rule.
        guard weightKG >= 0, weightKG <= 1000 else {
            throw ValidationError.liftedWeightOutOfRange(weightKG)
        }

        if let seconds {
            guard seconds > 0, seconds <= 60 * 60 else {
                throw ValidationError.restDurationOutOfRange(seconds)
            }
        } else {
            guard reps > 0, reps <= 1000 else {
                throw ValidationError.repsOutOfRange(reps)
            }
        }

        self.id = id
        self.weightKG = weightKG
        self.reps = reps
        self.seconds = seconds
        self.completedAt = completedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        weightKG = try container.decode(Double.self, forKey: .weightKG)
        reps = try container.decodeIfPresent(Int.self, forKey: .reps) ?? 0
        seconds = try container.decodeIfPresent(TimeInterval.self, forKey: .seconds)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
    }

    public var isTimed: Bool { seconds != nil }

    /// Nil for a hold: Epley counts repetitions, and a plank has none.
    public var estimatedOneRepMax: Double? {
        guard !isTimed else { return nil }
        return weightKG * (1 + Double(reps) / 30)
    }
}

/// One exercise within a session, and the sets done for it.
public struct WorkoutEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: String { exerciseID }

    public let exerciseID: String
    public var sets: [LoggedSet]

    /// Set instead of ``sets`` when the exercise is cardio. The two are never
    /// both populated: an exercise is lifted or it is not.
    public var cardio: CardioEffort?

    /// Ticked off by hand, without logging anything.
    ///
    /// The escape hatch for the sets you did but did not record — a warm-up, a
    /// machine whose stack you did not look at, an exercise done while the
    /// phone was in a locker. Without it the only way to clear a row is to type
    /// numbers, so the choice is between inventing figures and leaving the
    /// checklist permanently unfinished, and both are worse than saying "done,
    /// no detail".
    public var isMarkedDone: Bool

    /// Deliberately passed over, as opposed to simply not reached yet.
    ///
    /// The difference is the whole value of a checklist. An exercise with no
    /// sets at the end of a session might have been skipped for a reason or
    /// might have been forgotten, and coverage should count neither — but only
    /// the first should stop nagging.
    public var isSkipped: Bool

    public init(
        exerciseID: String,
        sets: [LoggedSet] = [],
        cardio: CardioEffort? = nil,
        isMarkedDone: Bool = false,
        isSkipped: Bool = false
    ) {
        self.exerciseID = exerciseID
        self.sets = sets
        self.cardio = cardio
        self.isMarkedDone = isMarkedDone
        self.isSkipped = isSkipped
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseID = try container.decode(String.self, forKey: .exerciseID)
        sets = try container.decodeIfPresent([LoggedSet].self, forKey: .sets) ?? []
        cardio = try container.decodeIfPresent(CardioEffort.self, forKey: .cardio)
        isMarkedDone = try container.decodeIfPresent(Bool.self, forKey: .isMarkedDone) ?? false
        isSkipped = try container.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
    }

    /// Three sets is a finished exercise unless you say otherwise.
    ///
    /// Not configurable, and deliberately so: three working sets is what the
    /// overwhelming majority of programmes prescribe, and the exercise can be
    /// ticked off by hand at any point — so the one case a setting would serve
    /// is already served by a tap, without a screen of numbers to fill in
    /// first.
    public static let setsForDone = 3

    /// Anything logged at all. This is what coverage counts: one set of rows
    /// trains lats whether or not three were planned.
    public var hasAnyWork: Bool { !sets.isEmpty || cardio != nil || isMarkedDone }

    /// Finished: three sets logged, cardio logged, or ticked off by hand.
    ///
    /// A hand-ticked exercise counts for coverage as well. It says "I did this
    /// and did not write down the numbers", and a muscle trained without a
    /// record of the weight is still a muscle trained — treating it as untrained
    /// would make the honest option the one that costs you.
    public var isDone: Bool {
        isMarkedDone || cardio != nil || sets.count >= Self.setsForDone
    }

    public var isOutstanding: Bool { !isDone && !isSkipped }

    /// "2/3" while it is being worked through, and just the count once it is
    /// past three — a fourth set is not a failure to stop at three.
    public var setProgress: String {
        sets.count >= Self.setsForDone
            ? "\(sets.count)"
            : "\(sets.count)/\(Self.setsForDone)"
    }

    /// Weight moved, in kilogram-reps. The usual definition of volume, and the
    /// one figure that makes two sessions of the same exercise comparable.
    /// Weight moved. A hold moves nothing, so it contributes nothing here —
    /// which is right: sixty seconds of plank is work, and it is not tonnage.
    public var volumeKG: Double {
        sets.reduce(0) { $0 + $1.weightKG * Double($1.reps) }
    }

    /// The longest hold, for an exercise measured in seconds.
    public var longestHold: LoggedSet? {
        sets.filter(\.isTimed).max { ($0.seconds ?? 0) < ($1.seconds ?? 0) }
    }

    public var heaviestSet: LoggedSet? {
        sets.max { left, right in
            left.weightKG == right.weightKG
                ? left.reps < right.reps
                : left.weightKG < right.weightKG
        }
    }
}

/// A workout: a day of the plan, performed on a date.
///
/// `dayName` is a copy, not a lookup. Renaming "Pull" to "Back day" must not
/// rewrite what last month's sessions were called — history records what
/// happened, and what it was called at the time is part of that. The `dayID`
/// is kept alongside for the cases where the live day genuinely is the subject,
/// such as "when did I last do this day".
public struct WorkoutSession: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var date: Date
    public let dayID: UUID
    public var dayName: String
    public var groups: [WorkoutGroup]
    public var entries: [WorkoutEntry]
    public var finishedAt: Date?

    public init(
        id: UUID = UUID(),
        date: Date = .now,
        dayID: UUID,
        dayName: String,
        groups: [WorkoutGroup],
        entries: [WorkoutEntry],
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.dayID = dayID
        self.dayName = dayName
        self.groups = groups
        self.entries = entries
        self.finishedAt = finishedAt
    }

    /// Builds the checklist from a day's picks.
    public init(startingFrom day: SplitDay, at date: Date = .now) {
        self.init(
            date: date,
            dayID: day.id,
            dayName: day.name,
            groups: day.groups,
            entries: day.exerciseIDs.map { WorkoutEntry(exerciseID: $0) }
        )
    }

    public var isFinished: Bool { finishedAt != nil }

    public var completedCount: Int { entries.filter(\.isDone).count }
    public var outstandingCount: Int { entries.filter(\.isOutstanding).count }

    public var totalSets: Int { entries.reduce(0) { $0 + $1.sets.count } }

    /// Time spent on cardio machines in this session.
    public var cardioSeconds: TimeInterval {
        entries.compactMap(\.cardio).reduce(0) { $0 + $1.seconds }
    }

    /// Whether anything at all was logged — sets or cardio.
    public var hasAnything: Bool { totalSets > 0 || cardioSeconds > 0 }
    public var volumeKG: Double { entries.reduce(0) { $0 + $1.volumeKG } }

    public var duration: TimeInterval? {
        finishedAt.map { $0.timeIntervalSince(date) }
    }

    /// The exercises actually performed — which is what coverage must be scored
    /// against, rather than the ones that were planned.
    ///
    /// The distinction is the point of logging at all. A pull day with the
    /// lat pulldown planned and skipped covers less back than the plan claimed,
    /// and a session that reported otherwise would be flattering you with your
    /// own intentions.
    public var performedExerciseIDs: [String] {
        entries.filter(\.hasAnyWork).map(\.exerciseID)
    }

    public func entry(_ exerciseID: String) -> WorkoutEntry? {
        entries.first { $0.exerciseID == exerciseID }
    }

    // MARK: - Editing

    public mutating func add(_ set: LoggedSet, to exerciseID: String) {
        guard let index = entries.firstIndex(where: { $0.exerciseID == exerciseID }) else {
            // An exercise added mid-session — the substitution you make when
            // the rack is taken. Appended rather than refused: the session is a
            // record of what happened, and what happened was not the plan.
            entries.append(WorkoutEntry(exerciseID: exerciseID, sets: [set]))
            return
        }
        entries[index].sets.append(set)
        entries[index].isSkipped = false
    }

    /// Records a cardio session against an exercise, replacing any earlier one.
    ///
    /// Replacing rather than appending, because the figures are totals for the
    /// whole session: two entries for one treadmill session would be two
    /// answers to the same question, and nothing could say which was right.
    public mutating func setCardio(_ effort: CardioEffort?, for exerciseID: String) {
        guard let index = entries.firstIndex(where: { $0.exerciseID == exerciseID }) else {
            guard let effort else { return }
            entries.append(WorkoutEntry(exerciseID: exerciseID, cardio: effort))
            return
        }
        entries[index].cardio = effort
        if effort != nil { entries[index].isSkipped = false }
    }

    public mutating func removeSet(_ setID: UUID, from exerciseID: String) {
        guard let index = entries.firstIndex(where: { $0.exerciseID == exerciseID }) else { return }
        entries[index].sets.removeAll { $0.id == setID }
    }

    /// Ticks an exercise off, or un-ticks it.
    public mutating func setMarkedDone(_ done: Bool, for exerciseID: String) {
        guard let index = entries.firstIndex(where: { $0.exerciseID == exerciseID }) else { return }
        entries[index].isMarkedDone = done
        if done { entries[index].isSkipped = false }
    }

    public mutating func setSkipped(_ skipped: Bool, for exerciseID: String) {
        guard let index = entries.firstIndex(where: { $0.exerciseID == exerciseID }) else { return }
        entries[index].isSkipped = skipped
    }

    public mutating func addExercise(_ exerciseID: String) {
        guard !entries.contains(where: { $0.exerciseID == exerciseID }) else { return }
        entries.append(WorkoutEntry(exerciseID: exerciseID))
    }

    public mutating func removeExercise(_ exerciseID: String) {
        entries.removeAll { $0.exerciseID == exerciseID }
    }
}
