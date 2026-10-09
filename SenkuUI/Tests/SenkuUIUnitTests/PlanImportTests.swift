import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// A week written by hand — or by a tool reading someone's spreadsheet — rather
/// than by the exporter: exercises by the names people use, groups as people
/// say them, no ids anywhere.
@MainActor
@Suite struct PlanImportTests {
    @MainActor
    private struct Device {
        let suite = UserDefaults(suiteName: "senku.planimport.\(UUID().uuidString)")!
        lazy var profiles = ProfileStore(defaults: suite)
        lazy var weights = WeightLogStore(defaults: suite)
        lazy var records = RecordStore(defaults: suite)
        lazy var library = ExerciseLibrary(defaults: suite)
        lazy var plans = TrainingPlanStore(defaults: suite)
        lazy var workouts = WorkoutStore(defaults: suite)
        lazy var cardioRecords = CardioRecordStore(defaults: suite)
        lazy var cardioPlans = CardioProtocolStore(defaults: suite)
        lazy var anime = AnimeStore(defaults: suite)
        lazy var water = WaterStore(defaults: suite)
        lazy var intake = IntakeStore(defaults: suite)

        @discardableResult
        mutating func load(_ json: String) throws -> ImportSummary {
            let document = try SenkuImportDocument.decode(Data(json.utf8))
            return SenkuImporter.apply(
                document, profiles: profiles, weights: weights, records: records,
                library: library, plans: plans, workouts: workouts,
                cardioRecords: cardioRecords, cardioPlans: cardioPlans,
                anime: anime, water: water, intake: intake
            )
        }
    }

    private let week = """
    {
      "customExercises": [
        { "name": "Towel Row", "equipment": "barbell", "regionIDs": ["back.lats"] }
      ],
      "plan": {
        "target": { "sets": 4, "reps": 8 },
        "days": [
          { "name": "Push", "groups": ["Chest", "shoulders", "Triceps"],
            "exerciseIDs": ["Bench", "incline bench", "catalogue.bench.closeGrip"] },
          { "name": "Pull", "groups": ["back", "biceps"],
            "exerciseIDs": ["Towel Row", "Lat Pulldown", "Hammer Curls"] }
        ]
      }
    }
    """

    @Test func namesAliasesAndPluralsAllResolve() throws {
        var device = Device()
        let summary = try device.load(week)

        #expect(summary.problems.isEmpty)
        let days = device.plans.days
        #expect(days.map(\.name) == ["Push", "Pull"])
        #expect(days[0].groups == [.chest, .shoulder, .tricep])
        #expect(days[0].exerciseIDs == [
            "catalogue.bench.flat", "catalogue.bench.inclineBarbell", "catalogue.bench.closeGrip",
        ])
        #expect(days[1].groups == [.back, .bicep])
        #expect(device.plans.plan.target == RepTarget(sets: 4, reps: 8))
    }

    /// The custom exercise is added first, so the plan in the same file can
    /// name it — which is the whole point of putting both in one file.
    @Test func aCustomExerciseFromTheSameFileCanBeNamed() throws {
        var device = Device()
        try device.load(week)

        let towel = try #require(device.library.custom.first { $0.name == "Towel Row" })
        #expect(device.plans.days[1].exerciseIDs.first == towel.id)
    }

    /// "RDL" is another name for two exercises. Guessing would put the wrong
    /// one in the plan without a word; saying so costs one line.
    @Test func anAmbiguousOrUnknownNameIsReportedAndTheRestKept() throws {
        var device = Device()
        let summary = try device.load("""
        { "plan": { "days": [
          { "name": "Legs", "groups": ["legs"], "exerciseIDs": ["RDL", "Moon Squat", "Back Squat"] }
        ] } }
        """)

        #expect(summary.problems.count == 2)
        #expect(summary.problems.contains { $0.contains("RDL") && $0.contains(" or ") })
        #expect(summary.problems.contains { $0.contains("Moon Squat") })
        #expect(device.plans.days.first?.exerciseIDs.count == 1)
    }

    @Test func groupsLeftOutComeFromTheExercises() throws {
        var device = Device()
        try device.load("""
        { "plan": { "days": [ { "name": "Arms", "exerciseIDs": ["Hammer Curl", "Skull Crusher", "Bench"] } ] } }
        """)

        #expect(device.plans.days.first?.groups == [.bicep, .tricep, .chest])
    }

    /// A plan file replaces the plan and nothing else.
    @Test func everythingElseIsLeftAlone() throws {
        var device = Device()
        _ = device.water.add(millilitres: 500)
        device.records.add(try PersonalRecord(exerciseID: "catalogue.bench.flat", weightKG: 100, reps: 5))
        try device.load(#"{ "plan": { "days": [ { "name": "Old", "exerciseIDs": ["Bench"] } ] } }"#)

        try device.load(week)

        #expect(device.water.entries.count == 1)
        #expect(device.records.records.count == 1)
        #expect(device.plans.days.map(\.name) == ["Push", "Pull"])
    }

    private static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // SenkuUIUnitTests
        .deletingLastPathComponent()      // Tests
        .deletingLastPathComponent()      // SenkuUI
        .deletingLastPathComponent()      // the repo

    /// The documented example is what people and tools copy from, so it has to
    /// import without a single complaint.
    @Test func theDocumentedExampleImportsCleanly() throws {
        let url = Self.repo.appendingPathComponent("docs/import-example.json")
        var device = Device()
        let summary = try device.load(String(contentsOf: url, encoding: .utf8))

        #expect(summary.problems.isEmpty, "\(summary.problems)")
        #expect(device.plans.days.map(\.name) == ["Push", "Pull", "Legs"])
        #expect(device.plans.days.allSatisfy { $0.exerciseIDs.count >= 3 })
        #expect(device.plans.days[2].groups == [.legs])
    }

    /// Targets written against the names a file used are kept against the
    /// exercises those names turned out to be.
    @Test func targetsFollowTheirExercisesThroughResolution() throws {
        var device = Device()
        let summary = try device.load("""
        { "plan": { "target": { "sets": 3, "reps": 8, "maxReps": 12 }, "days": [
          { "name": "Push", "exercises": [ "Bench", { "name": "OHP", "sets": 5, "reps": 5 } ] }
        ] } }
        """)

        #expect(summary.problems.isEmpty)
        let day = try #require(device.plans.days.first)
        #expect(day.exerciseIDs == ["catalogue.bench.flat", "catalogue.press.overheadBarbell"])
        #expect(day.targets == ["catalogue.press.overheadBarbell": RepTarget(sets: 5, reps: 5)])
        #expect(device.plans.plan.target == RepTarget(sets: 3, reps: 8, maxReps: 12))
    }

    /// The plan-import skill's worked example: what its checker passes, the app
    /// has to import the same way — numbers and all.
    @Test func theSkillsExampleImportsAsItsCheckerSays() throws {
        let url = Self.repo.appendingPathComponent("skills/senku-plan/examples/ppl-plan.senku.json")
        var device = Device()
        let summary = try device.load(String(contentsOf: url, encoding: .utf8))

        #expect(summary.problems.isEmpty, "\(summary.problems)")
        let days = device.plans.days
        #expect(days.map(\.name) == ["Push", "Pull", "Legs"])
        #expect(days.allSatisfy { $0.exerciseIDs.count == 5 })
        let plan = device.plans.plan
        #expect(plan.target == RepTarget(sets: 3, reps: 8, maxReps: 12))
        #expect(plan.target(for: "catalogue.bench.flat", on: days[0].id) == RepTarget(sets: 4, reps: 6, maxReps: 8))
        #expect(plan.target(for: "catalogue.press.overheadBarbell", on: days[0].id) == RepTarget(sets: 3, reps: 8))
        #expect(plan.target(for: "catalogue.squat.back", on: days[2].id) == RepTarget(sets: 4, reps: 6, maxReps: 8))
    }
}
