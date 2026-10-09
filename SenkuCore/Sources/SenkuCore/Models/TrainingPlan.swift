import Foundation

/// One training day: what it is called, what it trains, and what you do on it.
///
/// The unit the app calls a "split". A day rather than a week, because the week
/// is the arrangement and the day is the thing you actually walk into the gym
/// holding — "pull", with back and biceps in it, and the seven movements you
/// picked for it.
///
/// `groups` and `exerciseIDs` are kept separately on purpose. The groups are
/// the day's *intent*, and coverage is scored against them: a pull day with
/// nothing but rows is 100% of the rows you chose and about half a back, and
/// the only way to say so is to know that back was the target. Deriving the
/// intent from the exercises instead would make every day trivially complete.
public struct SplitDay: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var groups: [WorkoutGroup]
    /// Ordered: this is the order they are performed and shown in.
    public var exerciseIDs: [String]
    /// Sets and reps for the exercises that differ from the plan's, by id.
    /// Most days have none: an exercise without its own uses the plan's.
    public var targets: [String: RepTarget]

    public init(
        id: UUID = UUID(),
        name: String,
        groups: [WorkoutGroup],
        exerciseIDs: [String] = [],
        targets: [String: RepTarget] = [:]
    ) {
        self.id = id
        self.name = name
        self.groups = groups
        self.exerciseIDs = exerciseIDs
        self.targets = targets
    }

    public var isEmpty: Bool { exerciseIDs.isEmpty }

    /// The exercise's own target, or the plan's.
    public func target(for exerciseID: String, plan: RepTarget) -> RepTarget {
        targets[exerciseID] ?? plan
    }

    /// Lenient about what a hand-written plan leaves out: a day with no id is
    /// given one, and a day with no groups gets them from its exercises when
    /// it is imported. A stored day always has both.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        groups = try container.decodeIfPresent([WorkoutGroup].self, forKey: .groups) ?? []
        exerciseIDs = try container.decodeIfPresent([String].self, forKey: .exerciseIDs) ?? []
        targets = try container.decodeIfPresent([String: RepTarget].self, forKey: .targets) ?? [:]
    }
}

/// The week: an ordered list of days.
///
/// Deliberately not a calendar. A plan here says what days exist and in what
/// order, not which weekday each falls on — because nobody's training week
/// survives contact with a Tuesday, and an app that insists legs were "due
/// yesterday" is an app that is wrong about your life. Which day you do is
/// chosen on the day, from this list.
public struct TrainingPlan: Codable, Hashable, Sendable {
    public var days: [SplitDay]

    /// What a finished exercise looks like — the bar for "go heavier".
    public var target: RepTarget

    public init(days: [SplitDay] = [], target: RepTarget = .standard) {
        self.days = days
        self.target = target
    }

    private enum CodingKeys: String, CodingKey {
        case days, target
    }

    /// Plans saved before the target existed get the standard one.
    ///
    /// Days are read through ``WrittenDay``, which also takes the shapes a
    /// person writes — exercises with their own sets and reps inline, some of
    /// the numbers left out — and fills what is missing from this plan's
    /// target, the one thing a day on its own does not know.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let target = try container.decodeIfPresent(RepTarget.self, forKey: .target) ?? .standard
        let written = try container.decode([WrittenDay].self, forKey: .days)
        self.target = target
        days = written.map { $0.day(planTarget: target) }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(days, forKey: .days)
        try container.encode(target, forKey: .target)
    }

    /// The target for an exercise on a day: its own, the plan's, or the app's.
    public func target(for exerciseID: String, on dayID: UUID) -> RepTarget {
        day(dayID)?.target(for: exerciseID, plan: target) ?? target
    }

    public var isEmpty: Bool { days.isEmpty }

    public func day(_ id: UUID) -> SplitDay? {
        days.first { $0.id == id }
    }

    /// Every group the plan trains at all.
    ///
    /// The basis for the one question a plan can answer that a day cannot: what
    /// you have left out entirely. A plan of push and pull with no leg day is a
    /// choice; a plan that forgot legs is a mistake; and the app can point at
    /// it without knowing which this is.
    public var trainedGroups: Set<WorkoutGroup> {
        Set(days.flatMap(\.groups))
    }

    /// Muscles only. Cardio's absence is not a hole in a lifting plan — plenty
    /// of people deliberately do none — and listing it as one would turn a
    /// genuine warning ("nothing here trains legs") into a nag to be ignored.
    ///
    /// Forearms are left out for the same reason. Every pull trains the grip,
    /// and a week with no wrist curls in it is the usual week, not a mistake —
    /// so a plan that was complete before forearms became a group stays
    /// complete after.
    public var untrainedGroups: [WorkoutGroup] {
        let trained = trainedGroups
        return ExerciseCatalogue.bundled.workoutGroups
            .filter { $0.isMuscle && !Self.optionalGroups.contains($0) && !trained.contains($0) }
    }

    /// Muscle groups whose absence from a week is not worth pointing out.
    static let optionalGroups: Set<WorkoutGroup> = [.forearm]
}

/// The shapes people actually train, offered as starting points.
///
/// Templates carry the days and their groups, and no exercises at all. That is
/// the honest division of labour: the arrangement of a week is a well-worn
/// pattern worth handing someone, while which row they do is about their gym,
/// their shoulders and their preferences, and guessing at it would put a
/// barbell in the hands of someone who does not have one.
public enum SplitTemplate: String, CaseIterable, Identifiable, Sendable {
    case pushPullLegs
    case upperLower
    case arnold
    case bodyPart

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .pushPullLegs: "Push / Pull / Legs"
        case .upperLower: "Upper / Lower"
        case .arnold: "Chest+Back / Arms / Legs"
        case .bodyPart: "One group a day"
        }
    }

    public var detail: String {
        switch self {
        case .pushPullLegs: "Three days. The common one, and it scales to six."
        case .upperLower: "Two days. Everything twice a week if you run it twice."
        case .arnold: "Three days, pairing muscles that work together."
        case .bodyPart: "Six days, one group each. The most volume per group."
        }
    }

    public var days: [SplitDay] {
        switch self {
        case .pushPullLegs:
            [
                SplitDay(name: "Push", groups: [.chest, .shoulder, .tricep]),
                SplitDay(name: "Pull", groups: [.back, .bicep]),
                SplitDay(name: "Legs", groups: [.legs, .abs]),
            ]
        case .upperLower:
            [
                SplitDay(name: "Upper", groups: [.chest, .back, .shoulder, .bicep, .tricep]),
                SplitDay(name: "Lower", groups: [.legs, .abs]),
            ]
        case .arnold:
            [
                SplitDay(name: "Chest & back", groups: [.chest, .back]),
                SplitDay(name: "Arms & shoulders", groups: [.shoulder, .bicep, .tricep]),
                SplitDay(name: "Legs", groups: [.legs, .abs]),
            ]
        case .bodyPart:
            [
                SplitDay(name: "Chest", groups: [.chest]),
                SplitDay(name: "Back", groups: [.back]),
                SplitDay(name: "Shoulders", groups: [.shoulder]),
                SplitDay(name: "Arms", groups: [.bicep, .tricep]),
                SplitDay(name: "Legs", groups: [.legs]),
                SplitDay(name: "Abs", groups: [.abs]),
            ]
        }
    }

    public var plan: TrainingPlan { TrainingPlan(days: days) }
}

/// A day as a file may write it.
///
/// Everything ``SplitDay`` stores, plus the friendlier forms: `exercises` as
/// well as `exerciseIDs`, and each one either a plain name or an object with
/// its own numbers —
///
/// ```json
/// "exercises": [
///   "Bench",
///   { "name": "Squat", "sets": 5, "reps": 5 },
///   { "name": "Lat Pulldown", "minReps": 8, "maxReps": 12 }
/// ]
/// ```
///
/// A number left out comes from the plan: the pulldown above is the plan's
/// sets, at 8–12.
struct WrittenDay: Decodable {
    let day: SplitDay
    let written: [(exercise: String, sets: Int?, reps: Int?, maxReps: Int?)]

    private enum Keys: String, CodingKey {
        case exercises
    }

    private struct Item: Decodable {
        let exercise: String
        let sets: Int?
        let reps: Int?
        let maxReps: Int?

        private enum Keys: String, CodingKey {
            case name, exercise, id, sets, reps, minReps, maxReps
        }

        init(from decoder: any Decoder) throws {
            if let plain = try? decoder.singleValueContainer().decode(String.self) {
                exercise = plain
                sets = nil
                reps = nil
                maxReps = nil
                return
            }
            let container = try decoder.container(keyedBy: Keys.self)
            exercise = try container.decodeIfPresent(String.self, forKey: .name)
                ?? container.decodeIfPresent(String.self, forKey: .exercise)
                ?? container.decode(String.self, forKey: .id)
            sets = try container.decodeIfPresent(Int.self, forKey: .sets)
            reps = try container.decodeIfPresent(Int.self, forKey: .reps)
                ?? container.decodeIfPresent(Int.self, forKey: .minReps)
            maxReps = try container.decodeIfPresent(Int.self, forKey: .maxReps)
        }
    }

    init(from decoder: any Decoder) throws {
        var day = try SplitDay(from: decoder)
        let container = try decoder.container(keyedBy: Keys.self)
        let items = try container.decodeIfPresent([Item].self, forKey: .exercises) ?? []
        day.exerciseIDs += items.map(\.exercise)
        self.day = day
        self.written = items.map { ($0.exercise, $0.sets, $0.reps, $0.maxReps) }
    }

    func day(planTarget: RepTarget) -> SplitDay {
        var day = day
        for item in written where item.sets != nil || item.reps != nil || item.maxReps != nil {
            let reps = item.reps ?? planTarget.reps
            // A top given without a bottom keeps the plan's bottom; a bottom
            // given alone is a single figure, not the plan's range around it.
            let top = item.maxReps ?? (item.reps == nil ? planTarget.maxReps : nil)
            day.targets[item.exercise] = RepTarget(
                sets: item.sets ?? planTarget.sets,
                reps: reps,
                maxReps: top
            )
        }
        return day
    }
}
