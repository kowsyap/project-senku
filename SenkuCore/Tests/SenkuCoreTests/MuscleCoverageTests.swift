import Testing
import Foundation
@testable import SenkuCore

/// The shipped catalogue is data, and data rots quietly: a share that no longer
/// sums to one, or a contribution pointing at a region somebody renamed, would
/// not crash anything — it would just make every coverage figure subtly wrong.
@Suite("Exercise catalogue")
struct ExerciseCatalogueTests {
    let catalogue = ExerciseCatalogue.bundled

    @Test("The bundled catalogue loads")
    func bundledCatalogueLoads() {
        #expect(catalogue.exercises.count > 50)
        #expect(catalogue.muscleRegions.count > 15)
        #expect(!catalogue.workoutGroups.isEmpty)
    }

    @Test("Every group's regions sum to the whole group")
    func regionSharesSumToOne() {
        for group in catalogue.workoutGroups {
            let total = catalogue.regions(in: group).reduce(0) { $0 + $1.groupShare }
            #expect(abs(total - 1) < 0.001, "\(group.rawValue) sums to \(total)")
        }
    }

    @Test("Exercise ids are unique")
    func exerciseIDsAreUnique() {
        #expect(Set(catalogue.exercises.map(\.id)).count == catalogue.exercises.count)
    }

    @Test("Every contribution names a region that exists")
    func contributionsPointAtRealRegions() {
        let known = Set(catalogue.muscleRegions.map(\.id))
        for exercise in catalogue.exercises {
            for region in exercise.contributions.keys {
                #expect(known.contains(region), "\(exercise.id) trains unknown region \(region)")
            }
        }
    }

    @Test("Contributions are proportions, not arbitrary numbers")
    func contributionsAreInRange() {
        for exercise in catalogue.exercises {
            for (region, value) in exercise.contributions {
                #expect(value > 0 && value <= 1, "\(exercise.id) → \(region) is \(value)")
            }
        }
    }
}

@Suite("Muscle coverage")
struct MuscleCoverageTests {
    let catalogue = ExerciseCatalogue.bundled

    private func exercise(_ id: String) throws -> Exercise {
        try #require(catalogue.exercise(id), "catalogue is missing \(id)")
    }

    @Test("Nothing chosen covers nothing")
    func emptySelectionCoversNothing() {
        #expect(MuscleCoverage.of([], for: .chest, in: catalogue).fraction == 0)
    }

    @Test("One flat press is not a chest day")
    func flatBenchAloneLeavesMostOfTheChest() throws {
        let coverage = MuscleCoverage.of([try exercise("catalogue.bench.flat")], for: .chest, in: catalogue)

        // It owns the mid chest, which the catalogue puts at 45% of the group.
        #expect(coverage.fraction > 0.4)
        #expect(coverage.fraction < 0.6)

        // And the gaps it leaves are named, upper and lower.
        let gaps = Set(coverage.gaps.map(\.id))
        #expect(gaps.contains("chest.upper"))
        #expect(gaps.contains("chest.lower"))
    }

    @Test("Covering every region reads as the whole group")
    func coveringEveryRegionReachesOne() {
        let regions = catalogue.regions(in: .chest)
        let everything = Exercise(
            id: "test.everything",
            name: "Everything",
            equipment: .machine,
            workoutGroup: .chest,
            contributions: Dictionary(uniqueKeysWithValues: regions.map { ($0.id, 1.0) })
        )

        #expect(abs(MuscleCoverage.of([everything], for: .chest, in: catalogue).fraction - 1) < 0.001)
    }

    @Test("A second exercise for the same region adds almost nothing")
    func overlappingWorkDoesNotStack() throws {
        let flat = try exercise("catalogue.bench.flat")
        let dumbbell = try exercise("catalogue.bench.dumbbell")

        let one = MuscleCoverage.of([flat], for: .chest, in: catalogue).fraction
        let two = MuscleCoverage.of([flat, dumbbell], for: .chest, in: catalogue).fraction

        // Both own the mid chest. Doing both is not 90% of a chest day — the
        // cap at 1 per region is what stops five pressing variations scoring
        // higher than a day that trained the whole group.
        #expect(two - one < 0.05)
    }

    @Test("What a drop would cost is measured against the rest, not in the abstract")
    func marginalValueAccountsForOverlap() throws {
        let flat = try exercise("catalogue.bench.flat")
        let dumbbell = try exercise("catalogue.bench.dumbbell")

        let aloneValue = MuscleCoverage.marginalValue(
            of: dumbbell, within: [dumbbell], for: .chest, in: catalogue
        )
        let besideFlat = MuscleCoverage.marginalValue(
            of: dumbbell, within: [flat, dumbbell], for: .chest, in: catalogue
        )

        #expect(aloneValue > 0.4)
        #expect(besideFlat < 0.05)
    }

    @Test("The suggestion after a flat press is not another flat press")
    func suggestionsFillTheGap() throws {
        let flat = try exercise("catalogue.bench.flat")
        let suggested = MuscleCoverage.suggestions(for: .chest, given: [flat], in: catalogue, limit: 3)

        #expect(!suggested.isEmpty)

        // Everything offered adds something, and the best of them trains a
        // region the flat press does not.
        #expect(suggested.allSatisfy { $0.gain > 0 })
        let best = try #require(suggested.first)
        let untouched = Set(["chest.upper", "chest.lower"])
        #expect(!untouched.intersection(best.exercise.contributions.keys).isEmpty)
    }

    @Test("A custom exercise trains what the user said it trains")
    func customExerciseUsesPickedRegions() throws {
        let upper = try #require(catalogue.region("chest.upper"))
        let custom = try #require(
            Exercise.custom(name: "Landmine press", equipment: .barbell, regions: [upper])
        )

        #expect(custom.isCustom)
        let coverage = MuscleCoverage.of([custom], for: .chest, in: catalogue)
        #expect(abs(coverage.fraction - upper.groupShare) < 0.001)
    }

    @Test("A custom exercise with no muscles picked is not an exercise")
    func customExerciseNeedsRegions() {
        #expect(Exercise.custom(name: "Mystery", equipment: .cable, regions: []) == nil)
    }
}
