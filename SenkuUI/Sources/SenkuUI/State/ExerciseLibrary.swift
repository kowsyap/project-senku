import Foundation
import Observation
import SenkuCore

/// Every exercise the app can offer: the bundled catalogue, plus the ones the
/// user made up.
///
/// Kept as one lookup so nothing downstream has to ask *which* list a movement
/// came from to find its name. What does differ is `isCustom`, and that stays
/// visible wherever the difference matters — a custom exercise's muscle
/// contributions are derived from regions the user picked, so any coverage
/// figure resting on them is an estimate of their classification, not a
/// catalogue fact.
@Observable
public final class ExerciseLibrary {
    static let storageKey = "senku.customExercises.v1"

    private let defaults: UserDefaults
    public let catalogue: ExerciseCatalogue

    public private(set) var custom: [Exercise] = []

    public init(
        defaults: UserDefaults = SenkuStorage.shared,
        catalogue: ExerciseCatalogue = .bundled
    ) {
        self.defaults = defaults
        self.catalogue = catalogue
        self.custom = Self.load(from: defaults)
    }

    public var all: [Exercise] { catalogue.exercises + custom }

    public func exercise(_ id: String) -> Exercise? {
        catalogue.exercise(id) ?? custom.first { $0.id == id }
    }

    public func name(of id: String) -> String {
        exercise(id)?.name ?? id
    }

    /// What a plan written by hand can mean by an exercise.
    public enum Reference: Equatable {
        case found(Exercise)
        case missing
        /// More than one exercise goes by that name — "Hammer Curl" as an
        /// other name of two. Better said than guessed.
        case ambiguous([String])
    }

    /// The exercise a plan means: by id, then by name, then by another name.
    ///
    /// Names before aliases, so an exercise called what you typed beats one
    /// that is merely also known by it.
    public func exercise(named reference: String) -> Reference {
        if let exact = exercise(reference) { return .found(exact) }

        let key = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let byName = all.filter { $0.isNamed(key) }
        let direct = byName.filter { Self.sameName($0.name, key) }
        let candidates = direct.isEmpty ? byName : direct

        switch candidates.count {
        case 0: return .missing
        case 1: return .found(candidates[0])
        default: return .ambiguous(candidates.map(\.name))
        }
    }

    private static func sameName(_ name: String, _ reference: String) -> Bool {
        let lhs = Exercise.searchKey(name), rhs = Exercise.searchKey(reference)
        return lhs == rhs || lhs + "s" == rhs || lhs == rhs + "s"
    }

    /// Everything filed under a group, custom exercises last — they are yours,
    /// and easier to find at the end of a list you already know.
    public func exercises(in group: WorkoutGroup) -> [Exercise] {
        catalogue.exercises(in: group).sorted { $0.name < $1.name }
            + custom.filter { $0.workoutGroup == group }.sorted { $0.name < $1.name }
    }

    public func add(_ exercise: Exercise) {
        custom.removeAll { $0.id == exercise.id }
        custom.append(exercise)
        persist()
    }

    public func delete(_ exercise: Exercise) {
        custom.removeAll { $0.id == exercise.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(custom) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [Exercise] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Exercise].self, from: data)
        else { return [] }
        return decoded
    }
}
