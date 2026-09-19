import Foundation
import Testing
@testable import SenkuUI

/// The sample data ships inside the app and is loaded through the same importer
/// as anybody's backup, so if it stops decoding, so has everybody's backup.
///
/// It is also the only test that reads a file from the repository rather than
/// building its input, which is the point: the file is the thing being checked.
@MainActor
@Suite struct SampleDataTests {
    private var sample: URL {
        URL(fileURLWithPath: #filePath)           // …/SenkuUI/Tests/SenkuUIUnitTests/this.swift
            .deletingLastPathComponent()          // SenkuUIUnitTests
            .deletingLastPathComponent()          // Tests
            .deletingLastPathComponent()          // SenkuUI
            .deletingLastPathComponent()          // repository root
            .appendingPathComponent("Senku/Senku/sample-data.json")
    }

    @Test func itDecodes() throws {
        let document = try SenkuImportDocument.decode(try Data(contentsOf: sample))

        #expect(document.profile != nil)
        #expect((document.weighIns?.count ?? 0) >= 30)
        #expect((document.workouts?.count ?? 0) >= 5)
        #expect((document.water?.count ?? 0) >= 50)
        #expect((document.intake?.count ?? 0) >= 30)
        #expect(document.plan?.days.count == 4)
        #expect((document.records?.count ?? 0) >= 5)
        #expect((document.anime?.count ?? 0) >= 3)
    }

    /// Every exercise it names has to exist, or the screens it is meant to
    /// photograph come up with rows nothing can label.
    @Test func itOnlyNamesRealExercises() throws {
        let document = try SenkuImportDocument.decode(try Data(contentsOf: sample))
        let known = Set(ExerciseLibrary().catalogue.exercises.map(\.id))

        // Built up step by step: one expression of five optional arrays is
        // more than the type checker will sit through.
        var named: Set<String> = []
        for record in document.records ?? [] { named.insert(record.exerciseID) }
        for day in document.plan?.days ?? [] { named.formUnion(day.exerciseIDs) }
        for session in document.workouts ?? [] {
            for entry in session.entries { named.insert(entry.exerciseID) }
        }
        for record in document.cardioRecords ?? [] { named.insert(record.exerciseID) }
        for plan in document.cardioPlans ?? [] { named.insert(plan.exerciseID) }

        #expect(named.subtracting(known).isEmpty, "Unknown exercises: \(named.subtracting(known).sorted())")
    }

    /// Importing it twice must not double anything — the same guarantee a
    /// backup restored onto a live device needs.
    @Test func importingItTwiceChangesNothingTheSecondTime() throws {
        let suite = UserDefaults(suiteName: "senku.sample.\(UUID().uuidString)")!
        let document = try SenkuImportDocument.decode(try Data(contentsOf: sample))

        func apply() -> ImportSummary {
            SenkuImporter.apply(
                document,
                profiles: ProfileStore(defaults: suite),
                weights: WeightLogStore(defaults: suite),
                records: RecordStore(defaults: suite),
                library: ExerciseLibrary(defaults: suite),
                plans: TrainingPlanStore(defaults: suite),
                workouts: WorkoutStore(defaults: suite),
                cardioRecords: CardioRecordStore(defaults: suite),
                cardioPlans: CardioProtocolStore(defaults: suite),
                anime: AnimeStore(defaults: suite),
                water: WaterStore(defaults: suite),
                intake: IntakeStore(defaults: suite)
            )
        }

        let first = apply()
        #expect(first.waterAdded > 50)
        #expect(first.mealsAdded > 30)

        let second = apply()
        #expect(second.waterAdded == 0)
        #expect(second.mealsAdded == 0)
    }
}
