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

    // MARK: - Ranges

    /// 8–12 means twelve, on every set, before the weight goes up.
    @Test func aRangeIsEarnedAtItsTop() throws {
        let range = RepTarget(sets: 3, reps: 8, maxReps: 12)
        #expect(try entry([(40, 10), (40, 10), (40, 10)]).earnedStepUp(for: range) == nil)
        #expect(try entry([(40, 12), (40, 12), (40, 11)]).earnedStepUp(for: range) == nil)
        #expect(try entry([(40, 12), (40, 12), (40, 12)]).earnedStepUp(for: range) == 40)
    }

    @Test func aRangeThatIsNotOneIsOneFigure() {
        #expect(RepTarget(sets: 3, reps: 10, maxReps: 10).maxReps == nil)
        #expect(RepTarget(sets: 3, reps: 10, maxReps: 6).maxReps == nil)
        #expect(RepTarget(sets: 3, reps: 8, maxReps: 99).maxReps == 50)
        #expect(RepTarget(sets: 3, reps: 8, maxReps: 12).text == "3 × 8–12")
        #expect(RepTarget.standard.text == "3 × 10")
    }

    /// A target saved before ranges existed reads as the single figure it was,
    /// and a range survives the round trip.
    @Test func rangesRoundTripAndOldTargetsStillRead() throws {
        let old = try JSONDecoder().decode(RepTarget.self, from: Data(#"{"sets":4,"reps":6}"#.utf8))
        #expect(old == RepTarget(sets: 4, reps: 6))

        let range = RepTarget(sets: 3, reps: 8, maxReps: 12)
        let back = try JSONDecoder().decode(RepTarget.self, from: JSONEncoder().encode(range))
        #expect(back == range)

        let written = try JSONDecoder().decode(
            RepTarget.self, from: Data(#"{"sets":3,"minReps":6,"maxReps":8}"#.utf8)
        )
        #expect(written == RepTarget(sets: 3, reps: 6, maxReps: 8))
    }

    // MARK: - Written by hand

    private func plan(_ json: String) throws -> TrainingPlan {
        try JSONDecoder().decode(TrainingPlan.self, from: Data(json.utf8))
    }

    /// The exercise's own, then the plan's, then the app's — with each number
    /// an exercise leaves out taken from the plan.
    @Test func anExerciseTakesWhatItDoesNotSayFromThePlan() throws {
        let week = try plan("""
        { "target": { "sets": 4, "reps": 8, "maxReps": 12 },
          "days": [ { "name": "Push", "exercises": [
            "Bench",
            { "name": "Squat", "sets": 5, "reps": 5 },
            { "name": "Dips", "minReps": 6 },
            { "name": "Flyes", "maxReps": 15 },
            { "name": "Press", "sets": 2 }
          ] } ] }
        """)
        let day = try #require(week.days.first)
        let planned = week.target

        #expect(day.exerciseIDs == ["Bench", "Squat", "Dips", "Flyes", "Press"])
        #expect(day.target(for: "Bench", plan: planned) == planned)
        #expect(day.target(for: "Squat", plan: planned) == RepTarget(sets: 5, reps: 5))
        #expect(day.target(for: "Dips", plan: planned) == RepTarget(sets: 4, reps: 6))
        #expect(day.target(for: "Flyes", plan: planned) == RepTarget(sets: 4, reps: 8, maxReps: 15))
        #expect(day.target(for: "Press", plan: planned) == RepTarget(sets: 2, reps: 8, maxReps: 12))
    }

    @Test func aPlanWithNoTargetUsesTheAppsOwn() throws {
        let week = try plan(#"{ "days": [ { "name": "A", "exercises": [ { "name": "Row", "reps": 12 } ] } ] }"#)
        #expect(week.days[0].target(for: "Row", plan: week.target) == RepTarget(sets: 3, reps: 12))
        #expect(week.days[0].target(for: "Other", plan: week.target) == .standard)
    }

    @Test func aStoredPlanWithTargetsRoundTrips() throws {
        let day = SplitDay(
            name: "Legs", groups: [.legs], exerciseIDs: ["a", "b"],
            targets: ["a": RepTarget(sets: 5, reps: 5)]
        )
        let original = TrainingPlan(days: [day], target: RepTarget(sets: 3, reps: 8, maxReps: 12))
        let back = try JSONDecoder().decode(TrainingPlan.self, from: JSONEncoder().encode(original))
        #expect(back == original)
    }

    // MARK: - Done

    /// The checklist finishes an exercise at its own sets.
    @Test func anExerciseIsDoneAtItsTargetsSets() throws {
        let day = SplitDay(
            name: "Legs", groups: [.legs], exerciseIDs: ["squat", "curl"],
            targets: ["squat": RepTarget(sets: 5, reps: 5)]
        )
        var session = WorkoutSession(startingFrom: day, target: RepTarget(sets: 2, reps: 12))
        let set = try LoggedSet(weightKG: 100, reps: 5)

        session.entries[0].sets = Array(repeating: set, count: 4)
        session.entries[1].sets = Array(repeating: set, count: 2)
        #expect(!session.entries[0].isDone)
        #expect(session.entries[0].setProgress == "4/5")
        #expect(session.entries[1].isDone)

        session.entries[0].sets.append(set)
        #expect(session.entries[0].isDone)
    }

    /// Sessions from before targets travelled with them still finish at three.
    @Test func anOldSessionFinishesAtThree() throws {
        let old = try JSONDecoder().decode(
            WorkoutEntry.self, from: Data(#"{"exerciseID":"x","sets":[]}"#.utf8)
        )
        #expect(old.target == nil)
        #expect(old.setsToFinish == 3)
    }
}
