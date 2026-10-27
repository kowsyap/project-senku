import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// A set deleted from the workout in progress takes its record with it.
@Suite struct RemoveSetTests {
    private let bench = "catalogue.bench.flat"

    private func stores() -> (WorkoutStore, RecordStore) {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let workouts = WorkoutStore(defaults: defaults)
        workouts.start(SplitDay(name: "Push", groups: [.chest], exerciseIDs: [bench]))
        return (workouts, RecordStore(defaults: defaults))
    }

    @Test func deletingThePRSetDeletesThePR() throws {
        let (workouts, records) = stores()
        let set = try LoggedSet(weightKG: 100, reps: 5)
        #expect(workouts.log(set, for: bench, records: records) != nil)

        workouts.removeSet(set.id, from: bench, records: records)

        #expect(records.records.isEmpty)
    }

    /// 105 beat 100 only because it was there; with it gone, 100 is the record.
    @Test func theSetLeftBecomesTheRecord() throws {
        let (workouts, records) = stores()
        let heavy = try LoggedSet(weightKG: 105, reps: 5)
        let lighter = try LoggedSet(weightKG: 100, reps: 5)
        workouts.log(heavy, for: bench, records: records)
        #expect(workouts.log(lighter, for: bench, records: records) == nil)

        workouts.removeSet(heavy.id, from: bench, records: records)

        #expect(records.records.map(\.weightKG) == [100])
    }

    @Test func anOlderRecordIsLeftAlone() throws {
        let (workouts, records) = stores()
        records.add(try PersonalRecord(exerciseID: bench, weightKG: 90, reps: 5))
        let set = try LoggedSet(weightKG: 100, reps: 5)
        workouts.log(set, for: bench, records: records)

        workouts.removeSet(set.id, from: bench, records: records)

        #expect(records.records.map(\.weightKG) == [90])
    }
}
