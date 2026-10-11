import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// A pull-up is bodyweight unless you say otherwise, and says so on screen.
@Suite struct AddedWeightTests {
    /// The bug: a record typed once with a plate put that plate, unseen, on
    /// every pull-up after it.
    @Test func aBodyweightSetRecordsNothingUnlessWeightIsAdded() {
        #expect(AddedWeight.recorded(6.8, isBodyweight: true, adds: false) == 0)
        #expect(AddedWeight.recorded(6.8, isBodyweight: true, adds: true) == 6.8)
    }

    @Test func aLoadedExerciseRecordsItsWeight() {
        #expect(AddedWeight.recorded(40, isBodyweight: false, adds: false) == 40)
        #expect(AddedWeight.recorded(-3, isBodyweight: false, adds: false) == 0)
    }

    /// Added weight carries on from a set done today, not from a record or an
    /// old session.
    @Test func addedWeightCarriesOnlyFromTodaysLastSet() throws {
        #expect(!AddedWeight.startsOn(lastSetToday: nil))
        #expect(!AddedWeight.startsOn(lastSetToday: try LoggedSet(weightKG: 0, reps: 10)))
        #expect(AddedWeight.startsOn(lastSetToday: try LoggedSet(weightKG: 5, reps: 8)))
    }
}
