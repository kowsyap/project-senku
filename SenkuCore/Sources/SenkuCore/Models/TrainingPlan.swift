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

    public init(
        id: UUID = UUID(),
        name: String,
        groups: [WorkoutGroup],
        exerciseIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.groups = groups
        self.exerciseIDs = exerciseIDs
    }

    public var isEmpty: Bool { exerciseIDs.isEmpty }
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

    public init(days: [SplitDay] = []) {
        self.days = days
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
    public var untrainedGroups: [WorkoutGroup] {
        let trained = trainedGroups
        return ExerciseCatalogue.bundled.workoutGroups
            .filter { $0.isMuscle && !trained.contains($0) }
    }
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
