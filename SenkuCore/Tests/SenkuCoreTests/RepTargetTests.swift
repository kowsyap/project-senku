import Foundation
import Testing
@testable import SenkuCore

@Suite struct RepTargetTests {
    private func entry(_ sets: [(Double, Int)]) throws -> WorkoutEntry {
        WorkoutEntry(
            exerciseID: "catalogue.row.barbell",
            sets: try sets.map { try LoggedSet(weightKG: $0.0, reps: $0.1) }
        )
    }

    @Test func threeSetsOfTenEarnAStepUp() throws {
        let done = try entry([(40, 10), (40, 10), (40, 12)])
        #expect(done.earnedStepUp(for: .standard) == 40)
    }

    @Test func oneShortSetDoesNot() throws {
        let short = try entry([(40, 10), (40, 10), (40, 8)])
        #expect(short.earnedStepUp(for: .standard) == nil)
    }

    /// Finishing on a lighter weight is the sign the heavier one is not yet yours.
    @Test func droppingTheWeightToFinishDoesNot() throws {
        let dropped = try entry([(40, 10), (40, 10), (35, 10)])
        #expect(dropped.earnedStepUp(for: .standard) == nil)
    }

    @Test func lighterWarmUpsDoNotCount() throws {
        let warmed = try entry([(20, 10), (40, 10), (40, 10), (40, 10)])
        #expect(warmed.earnedStepUp(for: .standard) == 40)
    }

    @Test func aCustomTargetIsTheBar() throws {
        let five = try entry([(100, 5), (100, 5), (100, 5), (100, 5), (100, 5)])
        #expect(five.earnedStepUp(for: .standard) == nil)
        #expect(five.earnedStepUp(for: RepTarget(sets: 5, reps: 5)) == 100)
    }

    @Test func bodyweightCanEarnItToo() throws {
        let pullUps = try entry([(0, 10), (0, 11), (0, 10)])
        #expect(pullUps.earnedStepUp(for: .standard) == 0)
    }

    @Test func holdsNeverDo() throws {
        let plank = WorkoutEntry(
            exerciseID: "catalogue.plank",
            sets: try (0..<3).map { _ in try LoggedSet(weightKG: 0, seconds: 60) }
        )
        #expect(plank.earnedStepUp(for: .standard) == nil)
    }

    @Test func aPlanSavedBeforeTargetsGetsTheStandardOne() throws {
        let old = #"{"days":[]}"#.data(using: .utf8)!
        let plan = try JSONDecoder().decode(TrainingPlan.self, from: old)
        #expect(plan.target == .standard)
    }

    @Test func targetsAreKeptInRange() {
        let silly = RepTarget(sets: 0, reps: 500)
        #expect(silly.sets == 1)
        #expect(silly.reps == 50)
    }
}
