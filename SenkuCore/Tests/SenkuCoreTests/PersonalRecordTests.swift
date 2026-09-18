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

    @Test("A twenty-rep set never becomes the estimated max")
    func unreliableSetsAreExcludedFromTheEstimate() throws {
        let single = try record(100, 1)
        let endurance = try record(70, 25)  // would estimate ~128 if trusted

        let records = ExerciseRecords(exerciseID: "catalogue.bench.flat", records: [single, endurance])
        #expect(records.bestEstimated?.id == single.id)
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
}
