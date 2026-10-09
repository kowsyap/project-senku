import Testing
import Foundation
@testable import SenkuCore

/// Search is judged by what people type, not by what the catalogue calls
/// things. Every case here is a search somebody actually made and did not
/// find the exercise with.
@Suite("Exercise search")
struct ExerciseSearchTests {
    let catalogue = ExerciseCatalogue.bundled

    private func found(_ query: String) -> Set<String> {
        Set(catalogue.exercises.filter { $0.matches(query) }.map(\.name))
    }

    @Test("A gym name finds the formal one")
    func nicknameFindsFormalName() {
        #expect(found("skull crusher").contains("Lying EZ-Bar Triceps Extension"))
        #expect(found("RDL").isSuperset(of: ["Barbell Romanian Deadlift", "Dumbbell Romanian Deadlift"]))
        #expect(found("ohp").contains("Barbell Overhead Press"))
        #expect(found("hyperextension").contains("Back Extension"))
    }

    @Test("Spacing, hyphens and a plural do not matter")
    func spellingIsForgiven() {
        // Typed as one word and plural, exactly as it was when it failed.
        #expect(found("skullcrushers").contains("Lying EZ-Bar Triceps Extension"))
        #expect(found("dead hangs").contains("Dead Hang"))
        #expect(found("pull up").contains("Pull-Up"))
        #expect(found("pullups").contains("Pull-Up"))
        #expect(found("farmers walk").contains("Farmer's Carry"))
    }

    @Test("A match through another name says which one")
    func aliasIsReported() throws {
        let skull = try #require(catalogue.exercise("catalogue.tricepsExtension.skullCrusher"))
        #expect(skull.alias(matching: "skull") == "Skull Crusher")
        // Its own name matched, so there is nothing to explain.
        #expect(skull.alias(matching: "triceps extension") == nil)
    }

    @Test("Nothing typed finds nothing, and nonsense finds nothing")
    func emptyAndUnknownFindNothing() {
        #expect(found("").isEmpty)
        #expect(found("  - ").isEmpty)
        #expect(found("zzqx").isEmpty)
    }

    @Test("No other name is another exercise's real name")
    func aliasesDoNotShadowNames() {
        // "Hamstring Curl" may lead to both leg curls; "Squat" leading to a
        // different exercise *called* Squat would make search lie.
        let names = Set(catalogue.exercises.map { Exercise.searchKey($0.name) })
        for exercise in catalogue.exercises {
            for alias in exercise.aliases {
                let key = Exercise.searchKey(alias)
                #expect(
                    key == Exercise.searchKey(exercise.name) || !names.contains(key),
                    "\(exercise.name)'s alias \(alias) is another exercise's name"
                )
            }
        }
    }
}

@Suite("Forearms and the catalogue's additions")
struct ForearmTests {
    let catalogue = ExerciseCatalogue.bundled

    private func exercise(_ id: String) throws -> Exercise {
        try #require(catalogue.exercise(id), "catalogue is missing \(id)")
    }

    @Test("Forearms are a group of their own")
    func forearmIsAGroup() {
        #expect(catalogue.workoutGroups.contains(.forearm))
        #expect(WorkoutGroup.forearm.isMuscle)
        #expect(catalogue.regions(in: .forearm).count == 3)
    }

    @Test("Adding forearms leaves the biceps figure where it was")
    func bicepsCoverageIsUnchanged() throws {
        // 75% biceps × 1.0 + 25% brachialis × 0.35, exactly as before forearms
        // existed. A forearm region inside biceps would have moved this.
        let curl = try exercise("catalogue.curl.barbell")
        expectClose(MuscleCoverage.of([curl], for: .bicep, in: catalogue).fraction, 0.8375, tolerance: 0.001)
    }

    @Test("Where an exercise is filed does not change what it covers")
    func filingIsNotCoverage() throws {
        // Listed under forearms, where people look for it, and still worth
        // 75% × 0.45 + 25% × 1.0 of a biceps day, as it was under biceps.
        let reverse = try exercise("catalogue.curl.reverse")
        #expect(reverse.workoutGroup == .forearm)
        expectClose(MuscleCoverage.of([reverse], for: .bicep, in: catalogue).fraction, 0.5875, tolerance: 0.001)
    }

    @Test("Grip work counts toward forearms")
    func gripWorkCovers() throws {
        let hang = try exercise("catalogue.forearm.deadHang")
        let reverse = try exercise("catalogue.forearm.reverseWristCurl")
        let zottman = try exercise("catalogue.forearm.zottmanCurl")

        let coverage = MuscleCoverage.of([hang, reverse, zottman], for: .forearm, in: catalogue)
        expectClose(coverage.fraction, 1.0, tolerance: 0.001)
    }

    @Test("Holds are timed; carries are timed and loaded")
    func holdsAreTimed() throws {
        #expect(try exercise("catalogue.forearm.deadHang").isTimed)
        let carry = try exercise("catalogue.forearm.farmersCarry")
        #expect(carry.isTimed)
        // Not bodyweight, so the logger still asks what was carried.
        #expect(carry.equipment != .bodyweight)
        #expect(try !exercise("catalogue.forearm.wristCurl").isTimed)
    }

    @Test("A custom exercise can be timed")
    func customCanBeTimed() throws {
        let flexors = try #require(catalogue.region("forearm.flexors"))
        let timed = try #require(
            Exercise.custom(name: "Plate pinch", equipment: .bodyweight, regions: [flexors], isTimed: true)
        )
        #expect(timed.isTimed)
        #expect(timed.workoutGroup == .forearm)

        let plain = try #require(Exercise.custom(name: "Gripper", equipment: .bodyweight, regions: [flexors]))
        #expect(!plain.isTimed)
    }

    @Test("A custom exercise saved before aliases existed still loads")
    func oldCustomExerciseDecodes() throws {
        let json = """
        {"id":"custom.1","name":"Landmine press","equipment":"barbell",
         "workoutGroup":"shoulder","contributions":{"shoulder.frontDelts":1.0},"isCustom":true}
        """
        let decoded = try JSONDecoder().decode(Exercise.self, from: Data(json.utf8))
        #expect(decoded.aliases.isEmpty)
        #expect(!decoded.isTimed)
    }

    /// A plan names one exercise, so a name has to match whole — "curl" is a
    /// search for every curl and the name of none of them.
    @Test("A plan's name matches whole, not in part")
    func namedMatchesWhole() throws {
        let bench = try #require(catalogue.exercise("catalogue.bench.flat"))
        #expect(bench.isNamed("Barbell Bench Press"))
        #expect(bench.isNamed("bench"))
        #expect(bench.isNamed("flat-bench"))
        #expect(bench.isNamed("catalogue.bench.flat"))
        #expect(!bench.isNamed("press"))
        #expect(!bench.isNamed(""))
    }

    @Test("Groups are found by the words people use for them")
    func groupsByEverydayName() {
        let groups = catalogue.workoutGroups
        #expect(WorkoutGroup.named("Biceps", among: groups) == .bicep)
        #expect(WorkoutGroup.named("shoulders", among: groups) == .shoulder)
        #expect(WorkoutGroup.named("Leg", among: groups) == .legs)
        #expect(WorkoutGroup.named("CHEST", among: groups) == .chest)
        #expect(WorkoutGroup.named("glutes", among: groups) == nil)
    }
}
