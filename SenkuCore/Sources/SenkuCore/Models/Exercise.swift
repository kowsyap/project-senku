import Foundation

/// A day's focus: chest, back, legs and so on.
///
/// A wrapper around a string rather than an enum, because the catalogue is
/// data. A group added to the JSON should appear in the app without a Swift
/// change — abs were added exactly that way — and, more importantly, an unknown
/// group must not fail the decode of the whole file. The seven that exist today
/// are named as constants for call sites that legitimately know them.
public struct WorkoutGroup: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public var id: String { rawValue }

    public static let chest = WorkoutGroup("chest")
    public static let back = WorkoutGroup("back")
    public static let shoulder = WorkoutGroup("shoulder")
    public static let bicep = WorkoutGroup("bicep")
    public static let tricep = WorkoutGroup("tricep")
    public static let legs = WorkoutGroup("legs")
    public static let abs = WorkoutGroup("abs")

    /// Conditioning. A group by the app's reckoning and not by anatomy, which
    /// is why it is kept out of the muscle ring and given its own place: what
    /// it trains is a heart, and putting it in a circle of silhouettes would
    /// claim otherwise.
    public static let cardio = WorkoutGroup("cardio")

    /// Whether this is a muscle group at all.
    public var isMuscle: Bool { self != .cardio }

    /// "Upper chest" from "chest.upper" — for a heading, when the catalogue has
    /// no prettier name to offer.
    public var title: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

/// What an exercise is done with. Same reasoning as ``WorkoutGroup``.
public struct Equipment: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public static let barbell = Equipment("barbell")
    public static let dumbbell = Equipment("dumbbell")
    public static let machine = Equipment("machine")
    public static let cable = Equipment("cable")
    public static let bodyweight = Equipment("bodyweight")

    public var title: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

/// One part of a muscle group, and how much of that group it accounts for.
///
/// The share is what makes coverage mean anything. Chest is not one muscle
/// trained one way: the mid chest is 45% of it, the upper 30%, the lower 25%,
/// and a day of flat pressing leaves the other 55% untouched however many sets
/// it runs to. Shares within a group sum to 1.
public struct MuscleRegion: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let workoutGroup: WorkoutGroup
    public let groupShare: Double

    public init(id: String, name: String, workoutGroup: WorkoutGroup, groupShare: Double) {
        self.id = id
        self.name = name
        self.workoutGroup = workoutGroup
        self.groupShare = groupShare
    }
}

/// A movement, and what it actually trains.
///
/// `contributions` is the heart of it: a region id mapped to how much of that
/// region this exercise trains, where 1 means "this is the exercise for it".
/// Flat bench is `chest.mid: 1.0` with triceps and front delts along for the
/// ride at 0.4 and 0.35 — which is why a chest day of nothing but flat bench
/// is not a chest day.
public struct Exercise: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let equipment: Equipment
    /// Plain-language muscles, as the catalogue names them, for the info sheet.
    public let targetMuscles: [String]
    public let workoutGroup: WorkoutGroup
    public let contributions: [String: Double]

    /// What a cardio machine reports, beyond the clock.
    ///
    /// Empty for everything that is lifted: a bench press has no speed. For
    /// cardio it is the short list of figures that exercise can actually tell
    /// you — speed and incline on a treadmill, distance and split on a rower —
    /// so the logger asks for those and not for a generic set of fields that
    /// are blank three times out of four.
    ///
    /// Time is not in the list. Every cardio session has a duration, so it is
    /// asked for always and named nowhere.
    public let cardioMetrics: [CardioMetric]

    /// Held rather than repeated: a plank, a wall sit, a hollow hold.
    ///
    /// The unit of work is seconds, not reps, and everything downstream needs
    /// to know — the logger asks for a duration, the record page ranks by the
    /// longest hold, and the estimated one-rep max is suppressed, because Epley
    /// is a rep-count formula and applying it to a hold produces a confident
    /// number that means nothing.
    public let isTimed: Bool

    /// Whether the user made this up. Kept because a custom exercise's
    /// contributions are derived from muscles *they* picked, so anything
    /// computed from them is an estimate resting on their classification — and
    /// the app says so rather than presenting it as catalogue fact.
    public let isCustom: Bool

    public init(
        id: String,
        name: String,
        description: String = "",
        equipment: Equipment,
        targetMuscles: [String] = [],
        workoutGroup: WorkoutGroup,
        contributions: [String: Double],
        cardioMetrics: [CardioMetric] = [],
        isTimed: Bool = false,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.equipment = equipment
        self.targetMuscles = targetMuscles
        self.workoutGroup = workoutGroup
        self.contributions = contributions
        self.cardioMetrics = cardioMetrics
        self.isTimed = isTimed
        self.isCustom = isCustom
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        equipment = try container.decode(Equipment.self, forKey: .equipment)
        targetMuscles = try container.decodeIfPresent([String].self, forKey: .targetMuscles) ?? []
        workoutGroup = try container.decode(WorkoutGroup.self, forKey: .workoutGroup)
        contributions = try container.decode([String: Double].self, forKey: .contributions)
        cardioMetrics = try container.decodeIfPresent([CardioMetric].self, forKey: .cardioMetrics) ?? []
        isTimed = try container.decodeIfPresent(Bool.self, forKey: .isTimed) ?? false
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }

    public var isCardio: Bool { workoutGroup == .cardio }

    /// Builds one from muscles the user chose.
    ///
    /// The picked regions are treated as primary and share a full unit of work
    /// between them, which is the most that can be claimed for a movement
    /// nobody has classified: it says "this trains these", not "this trains
    /// these in these proportions", because the user was not asked that.
    public static func custom(
        name: String,
        equipment: Equipment,
        regions: [MuscleRegion],
        id: String = "custom.\(UUID().uuidString)"
    ) -> Exercise? {
        guard !regions.isEmpty else { return nil }

        var contributions: [String: Double] = [:]
        for region in regions {
            contributions[region.id] = 1.0
        }

        return Exercise(
            id: id,
            name: name,
            equipment: equipment,
            targetMuscles: regions.map(\.name),
            workoutGroup: regions[0].workoutGroup,
            contributions: contributions,
            isCustom: true
        )
    }
}

/// Every exercise the app knows, and the muscle map they are scored against.
///
/// Loaded from JSON bundled with `SenkuCore` rather than written in Swift, so
/// the list can grow without a code change and can be checked by eye as data.
/// The shipped file is validated by tests: shares that sum to one per group,
/// unique ids, and no contribution pointing at a region that does not exist.
public struct ExerciseCatalogue: Codable, Sendable {
    public let schemaVersion: Int
    public let catalogueID: String
    public let workoutGroups: [WorkoutGroup]
    public let muscleRegions: [MuscleRegion]
    public let exercises: [Exercise]

    public init(
        schemaVersion: Int = 1,
        catalogueID: String = "senku.exerciseCatalogue",
        workoutGroups: [WorkoutGroup],
        muscleRegions: [MuscleRegion],
        exercises: [Exercise]
    ) {
        self.schemaVersion = schemaVersion
        self.catalogueID = catalogueID
        self.workoutGroups = workoutGroups
        self.muscleRegions = muscleRegions
        self.exercises = exercises
    }

    /// The bundled catalogue.
    ///
    /// Decoded once. A failure here is a broken build rather than a runtime
    /// condition worth handling — the file ships inside the package — so it
    /// traps with the reason rather than returning an empty catalogue that
    /// would quietly make every coverage figure zero.
    public static let bundled: ExerciseCatalogue = {
        guard let url = Bundle.module.url(forResource: "ExerciseCatalogue", withExtension: "json") else {
            preconditionFailure("ExerciseCatalogue.json is missing from the SenkuCore bundle")
        }
        do {
            return try JSONDecoder().decode(ExerciseCatalogue.self, from: Data(contentsOf: url))
        } catch {
            preconditionFailure("ExerciseCatalogue.json could not be decoded: \(error)")
        }
    }()

    // MARK: - Lookups

    public func exercise(_ id: String) -> Exercise? {
        exercises.first { $0.id == id }
    }

    public func region(_ id: String) -> MuscleRegion? {
        muscleRegions.first { $0.id == id }
    }

    /// The regions that make up a group, largest share first — which is also
    /// the order in which their absence matters.
    public func regions(in group: WorkoutGroup) -> [MuscleRegion] {
        muscleRegions
            .filter { $0.workoutGroup == group }
            .sorted { $0.groupShare > $1.groupShare }
    }

    public func exercises(in group: WorkoutGroup) -> [Exercise] {
        exercises.filter { $0.workoutGroup == group }
    }

    /// Every exercise that trains any part of a group, including those filed
    /// under another one. A chest day gains from dips whether or not the
    /// catalogue calls dips a chest exercise.
    public func exercisesTouching(_ group: WorkoutGroup) -> [Exercise] {
        let ids = Set(regions(in: group).map(\.id))
        return exercises.filter { !$0.contributions.keys.filter(ids.contains).isEmpty }
    }
}
