import Foundation

/// How much of a muscle group a set of exercises actually trains.
///
/// ## What it answers
///
/// "I am doing chest today, and I have picked flat bench and cable flyes — what
/// am I missing?" The honest answer is a proportion of the group left untouched
/// and the name of the part it belongs to, which is more use than a number on
/// its own: *"No lower-chest work. Decline press or dips would add 18%."*
///
/// ## The arithmetic, stated
///
/// ```
/// regionCoverage(r) = min(1, Σ contributions of the chosen exercises to r)
/// groupCoverage     = Σ over the group's regions: regionCoverage(r) × share(r)
/// ```
///
/// The cap at 1 is the important line. Three exercises each contributing 0.6 to
/// the mid chest do not train it 180%; they train it, and the second and third
/// buy far less than the first. Without the cap, a day of five pressing
/// variations would score higher than a day that covered the whole group, which
/// is precisely backwards.
///
/// ## What it is not
///
/// Coverage is not volume. It says every part of the group was trained, not
/// that any of it was trained *enough* — four hard sets and one lazy one score
/// identically. Sets-per-week guidance is a separate feature with its own
/// evidence base, and conflating the two would let the app imply a
/// recommendation it has not made.
public struct MuscleCoverage: Hashable, Sendable {
    /// One region's share of the group, and how much of it is trained.
    public struct Region: Hashable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// The part of the group this region accounts for, 0–1.
        public let share: Double
        /// How much of the region is trained, 0–1.
        public let covered: Double

        /// What covering this region completely would add to the group figure.
        public var remainingValue: Double { (1 - covered) * share }

        public var isCovered: Bool { covered >= 0.5 }
    }

    public let group: WorkoutGroup
    public let regions: [Region]

    /// The headline: the proportion of the group trained, 0–1.
    public var fraction: Double {
        regions.reduce(0) { $0 + $1.covered * $1.share }
    }

    public var percentage: Int { Int((fraction * 100).rounded()) }

    /// The regions worth naming as missing, biggest gap first. A region that is
    /// mostly covered is not a gap; it is a detail.
    public var gaps: [Region] {
        regions
            .filter { $0.covered < 0.5 && $0.remainingValue >= 0.05 }
            .sorted { $0.remainingValue > $1.remainingValue }
    }

    // MARK: - Computing

    /// Scores a selection against a group.
    public static func of(
        _ exercises: [Exercise],
        for group: WorkoutGroup,
        in catalogue: ExerciseCatalogue = .bundled
    ) -> MuscleCoverage {
        let regions = catalogue.regions(in: group).map { region in
            let total = exercises.reduce(0.0) { $0 + ($1.contributions[region.id] ?? 0) }
            return Region(
                id: region.id,
                name: region.name,
                share: region.groupShare,
                covered: min(1, total)
            )
        }
        return MuscleCoverage(group: group, regions: regions)
    }

    /// What dropping one exercise would cost.
    ///
    /// The marginal figure, not the exercise's own contribution — those differ
    /// whenever two movements overlap, and the difference is the point. The
    /// second flat-press variation in a day scores near zero here while looking
    /// substantial on its own, which is exactly what someone choosing what to
    /// cut needs to know.
    public static func marginalValue(
        of exercise: Exercise,
        within selection: [Exercise],
        for group: WorkoutGroup,
        in catalogue: ExerciseCatalogue = .bundled
    ) -> Double {
        let withIt = of(selection, for: group, in: catalogue).fraction
        let withoutIt = of(
            selection.filter { $0.id != exercise.id },
            for: group,
            in: catalogue
        ).fraction
        return withIt - withoutIt
    }

    /// What to add next, best first.
    ///
    /// Ranked by what each would *add* to this selection rather than by what it
    /// trains in the abstract, so the suggestion after flat bench is an incline
    /// or a decline press and never a second flat one.
    public static func suggestions(
        for group: WorkoutGroup,
        given selection: [Exercise],
        in catalogue: ExerciseCatalogue = .bundled,
        limit: Int = 3
    ) -> [(exercise: Exercise, gain: Double)] {
        let current = of(selection, for: group, in: catalogue).fraction
        let chosen = Set(selection.map(\.id))

        return catalogue.exercisesTouching(group)
            .filter { !chosen.contains($0.id) }
            .map { candidate in
                let gain = of(selection + [candidate], for: group, in: catalogue).fraction - current
                return (exercise: candidate, gain: gain)
            }
            .filter { $0.gain > 0.001 }
            .sorted { $0.gain > $1.gain }
            .prefix(limit)
            .map { $0 }
    }
}
