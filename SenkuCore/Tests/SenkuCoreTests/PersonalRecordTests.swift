import Testing
import Foundation
@testable import SenkuCore

/// Records are the one number in a gym app people genuinely care about, so
/// these are mostly about what the app refuses to blur together.
@Suite("Personal records")
struct PersonalRecordTests {
    let day = Date(timeIntervalSince1970: 1_700_000_000)

    private func record(
        _ weight: Double,
        _ reps: Int,
        daysAgo: Double = 0,
        source: PersonalRecord.Source = .manual
    ) throws -> PersonalRecord {
        try PersonalRecord(
            exerciseID: "catalogue.bench.flat",
            weightKG: weight,
            reps: reps,
            date: day.addingTimeInterval(-daysAgo * 86_400),
            source: source
        )
    }

    // MARK: - Estimating

    @Test("A single is its own estimate, with no formula applied")
    func singleNeedsNoEstimate() throws {
        #expect(try record(100, 1).estimatedOneRepMax == 100)
    }

    @Test("Epley is what the estimate uses")
    func estimateUsesEpley() throws {
        // 100 × 5 → 100 × (1 + 5/30) ≈ 116.7
        let estimate = try #require(record(100, 5).estimatedOneRepMax)
        #expect(abs(estimate - 116.667) < 0.01)
    }

    @Test("Past ten reps the estimate stops claiming to mean anything")
    func highRepSetsAreNotReliableEstimates() throws {
        #expect(try record(60, 8).isReliableEstimate)
        #expect(try !record(60, 20).isReliableEstimate)
    }

    // MARK: - Headlines

    @Test("Heaviest and best estimate are different questions")
    func heaviestAndEstimatedAreSeparate() throws {
        let heavySingle = try record(120, 1)
        let volumeSet = try record(100, 8)  // estimate ≈ 126.7

        let records = ExerciseRecords(
            exerciseID: "catalogue.bench.flat",
            records: [heavySingle, volumeSet]
        )

        #expect(records.heaviest?.weightKG == 120)
        #expect(records.bestEstimated?.id == volumeSet.id)
    }

    @Test("At equal weight, more reps is the better record")
    func moreRepsWinsAtEqualWeight() throws {
        let three = try record(100, 3)
        let five = try record(100, 5)

        let records = ExerciseRecords(exerciseID: "catalogue.bench.flat", records: [three, five])
        #expect(records.heaviest?.id == five.id)
    }

    @Test("A twenty-five-rep set counts as ten, and does not flatter")
    func highRepSetsCountAtTheLimit() throws {
        let single = try record(100, 1)
        let endurance = try record(70, 25)  // ~128 if all 25 were trusted; ~93.3 at ten

        let records = ExerciseRecords(exerciseID: "catalogue.bench.flat", records: [single, endurance])
        #expect(records.bestEstimated?.id == single.id)
        expectClose(try #require(endurance.estimatedOneRepMax), 70 * (1 + 10.0 / 30), tolerance: 0.001)
    }

    /// The case that showed the old rule was wrong: shrugs, done for high reps,
    /// where discarding every set past ten left last week's weaker set as the
    /// best estimate after a heavier, longer one.
    @Test("A heavier set past ten reps replaces a weaker estimate")
    func aHeavierHighRepSetMovesTheEstimate() throws {
        let lastWeek = try record(35, 10, daysAgo: 7)  // ≈ 46.7
        let thisWeek = try record(40, 15)              // counted as 40 × 10 ≈ 53.3

        let records = ExerciseRecords(exerciseID: "catalogue.bench.flat", records: [lastWeek, thisWeek])
        #expect(records.bestEstimated?.id == thisWeek.id)
        expectClose(try #require(thisWeek.estimatedOneRepMax), 53.333, tolerance: 0.001)

        // And it says it is a floor, where the 35 × 10 is not.
        #expect(thisWeek.isEstimateLowerBound)
        #expect(!lastWeek.isEstimateLowerBound)
    }

    @Test("A bodyweight set has nothing to estimate from")
    func bodyweightIsNotAnEstimate() throws {
        let records = ExerciseRecords(exerciseID: "catalogue.bench.flat", records: [try record(0, 12)])
        #expect(records.bestEstimated == nil)
    }

    @Test("A heavier lift does not always raise the estimated single")
    func aHeavierLiftNeedNotRaiseTheEstimate() throws {
        // 100 × 8 estimates ~126.7. A new 110 × 3 estimates ~121 — a heavier
        // bar, a *lower* implied single, so the estimate legitimately stays
        // where it was. The screen showing an unchanged figure after a new
        // record is this, not a stale view.
        let volume = try record(100, 8)
        let heavier = try record(110, 3)
        let records = ExerciseRecords(exerciseID: "catalogue.bench.flat", records: [volume, heavier])

        #expect(records.heaviest?.id == heavier.id)
        #expect(records.bestEstimated?.id == volume.id)

        // And a set that does beat it moves the figure.
        let better = try record(120, 3)  // ≈ 132
        let updated = ExerciseRecords(
            exerciseID: "catalogue.bench.flat",
            records: [volume, heavier, better]
        )
        #expect(updated.bestEstimated?.id == better.id)
    }

    // MARK: - Beating a record

    @Test("Anything is a record when there is nothing to beat")
    func firstLiftIsARecord() {
        let book = RecordBook([])
        #expect(book.wouldBeRecord(exerciseID: "catalogue.bench.flat", weightKG: 60, reps: 5))
    }

    @Test("More weight than has ever been on the bar is a record")
    func heavierIsARecord() throws {
        let book = RecordBook([try record(100, 5)])
        #expect(book.wouldBeRecord(exerciseID: "catalogue.bench.flat", weightKG: 105, reps: 1))
    }

    @Test("The same weight for more reps is a record too")
    func sameWeightMoreRepsIsARecord() throws {
        let book = RecordBook([try record(100, 3)])
        #expect(book.wouldBeRecord(exerciseID: "catalogue.bench.flat", weightKG: 100, reps: 5))
    }

    @Test("More reps at the heaviest weight is a record past ten reps too")
    func moreRepsPastTheLimitIsARecord() throws {
        // Both estimate as 40 × 10, so only the reps rule can tell them apart.
        let book = RecordBook([try record(40, 12)])
        #expect(book.wouldBeRecord(exerciseID: "catalogue.bench.flat", weightKG: 40, reps: 15))
        #expect(!book.wouldBeRecord(exerciseID: "catalogue.bench.flat", weightKG: 40, reps: 11))
    }

    @Test("A logged set and a record agree on the same lift")
    func loggedSetAndRecordAgree() throws {
        for (weight, reps) in [(100.0, 1), (100, 5), (40, 15)] {
            let set = try LoggedSet(weightKG: weight, reps: reps)
            let record = try record(weight, reps)
            expectClose(try #require(set.estimatedOneRepMax), try #require(record.estimatedOneRepMax), tolerance: 0.0001)
        }
    }

    @Test("A lighter, easier set is not")
    func lighterSetIsNotARecord() throws {
        let book = RecordBook([try record(100, 5)])
        #expect(!book.wouldBeRecord(exerciseID: "catalogue.bench.flat", weightKG: 90, reps: 3))
    }

    @Test("The same weight for the same reps is already recorded")
    func duplicateLiftsAreRecognised() throws {
        let book = RecordBook([try record(100, 5)])

        #expect(book.existingRecord(exerciseID: "catalogue.bench.flat", weightKG: 100, reps: 5) != nil)
        // A hair either side is the same lift after a trip through pounds.
        #expect(book.existingRecord(exerciseID: "catalogue.bench.flat", weightKG: 100.005, reps: 5) != nil)

        #expect(book.existingRecord(exerciseID: "catalogue.bench.flat", weightKG: 100, reps: 6) == nil)
        #expect(book.existingRecord(exerciseID: "catalogue.bench.flat", weightKG: 102.5, reps: 5) == nil)
        #expect(book.existingRecord(exerciseID: "catalogue.squat.back", weightKG: 100, reps: 5) == nil)
    }

    @Test("A record on one exercise says nothing about another")
    func recordsAreForOneExerciseOnly() throws {
        let book = RecordBook([try record(200, 1)])
        #expect(book.wouldBeRecord(exerciseID: "catalogue.squat.back", weightKG: 40, reps: 5))
    }

    // MARK: - Sources and staleness

    @Test("Logged and manual are both kept, and stay distinguishable")
    func loggedAndManualCoexist() throws {
        let setID = UUID()
        let logged = try record(100, 5, source: .logged(setID: setID))
        let typed = try record(110, 3, source: .manual)

        let records = ExerciseRecords(exerciseID: "catalogue.bench.flat", records: [logged, typed])

        #expect(records.records.count == 2)
        #expect(records.heaviest?.source == .manual)
        #expect(records.records.contains { $0.source.isLogged })
    }

    @Test("A lift untouched for months reads as stale")
    func oldRecordsAreStale() throws {
        let old = ExerciseRecords(
            exerciseID: "catalogue.bench.flat",
            records: [try record(100, 5, daysAgo: 90)]
        )
        let fresh = ExerciseRecords(
            exerciseID: "catalogue.bench.flat",
            records: [try record(100, 5, daysAgo: 10)]
        )

        #expect(old.isStale(at: day))
        #expect(!fresh.isStale(at: day))
    }

    @Test("Nonsense is refused rather than recorded")
    func invalidRecordsAreRefused() {
        #expect(throws: ValidationError.self) {
            _ = try PersonalRecord(exerciseID: "x", weightKG: -5, reps: 5)
        }
        #expect(throws: ValidationError.self) {
            _ = try PersonalRecord(exerciseID: "x", weightKG: 100, reps: 0)
        }
    }

    @Test("A bodyweight set is a lift with no weight on it")
    func bodyweightSetsAreRecordable() throws {
        let pullUps = try PersonalRecord(exerciseID: "catalogue.pullup", weightKG: 0, reps: 12)

        #expect(pullUps.isBodyweightOnly)
        // Twelve pull-ups beat ten, which is the only comparison that means
        // anything when the load never changes.
        let book = RecordBook([pullUps])
        #expect(book.wouldBeRecord(exerciseID: "catalogue.pullup", weightKG: 5, reps: 3))
        #expect(!book.wouldBeRecord(exerciseID: "catalogue.pullup", weightKG: 0, reps: 8))
    }

    /// Typed in by hand, a lighter lift is not a record — even one whose
    /// estimated single is higher, which a logged set would be allowed.
    @Test func aRecordAddedByHandHasToBeHeavierOrMoreReps() throws {
        let book = RecordBook([try record(20, 12)])
        let id = "catalogue.bench.flat"

        #expect(!book.beatsBest(exerciseID: id, weightKG: 17.5, reps: 10))
        #expect(!book.beatsBest(exerciseID: id, weightKG: 17.5, reps: 20))
        #expect(!book.beatsBest(exerciseID: id, weightKG: 20, reps: 12))
        #expect(!book.beatsBest(exerciseID: id, weightKG: 20, reps: 8))
        #expect(book.beatsBest(exerciseID: id, weightKG: 20, reps: 13))
        #expect(book.beatsBest(exerciseID: id, weightKG: 22.5, reps: 1))
        #expect(book.beatsBest(exerciseID: "catalogue.squat.back", weightKG: 5, reps: 1))
    }

    @Test func aHoldAddedByHandHasToBeLonger() throws {
        let plank = try PersonalRecord(exerciseID: "catalogue.abs.plank", weightKG: 0, seconds: 120, date: day)
        let book = RecordBook([plank])
        let id = "catalogue.abs.plank"

        #expect(!book.beatsBest(exerciseID: id, weightKG: 0, reps: 0, seconds: 90))
        #expect(!book.beatsBest(exerciseID: id, weightKG: 0, reps: 0, seconds: 120))
        #expect(book.beatsBest(exerciseID: id, weightKG: 10, reps: 0, seconds: 120))
        #expect(book.beatsBest(exerciseID: id, weightKG: 0, reps: 0, seconds: 125))
    }
}
