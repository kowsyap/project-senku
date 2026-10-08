import Foundation
import Testing
@testable import SenkuCore

@Suite("Workout energy")
struct WorkoutEnergyTests {
    /// The worked example: 80 kg, 40 minutes.
    @Test("Active energy is (MET − 1) × kg × hours")
    func activeEnergyFormula() {
        let forty: TimeInterval = 40 * 60
        expectClose(WorkoutEnergy.activeKilocalories(effort: .light, weightKG: 80, duration: forty), 2.5 * 80 * (40.0 / 60), tolerance: 0.001)
        expectClose(WorkoutEnergy.activeKilocalories(effort: .vigorous, weightKG: 80, duration: forty), 5 * 80 * (40.0 / 60), tolerance: 0.001)
    }

    @Test("The two efforts are the Compendium's figures")
    func effortsAreCited() {
        #expect(WorkoutEnergy.Effort.light.met == 3.5)
        #expect(WorkoutEnergy.Effort.vigorous.met == 6.0)
    }

    @Test("No weight or no time is no estimate")
    func nothingFromNothing() {
        #expect(WorkoutEnergy.activeKilocalories(effort: .vigorous, weightKG: 0, duration: 3600) == 0)
        #expect(WorkoutEnergy.activeKilocalories(effort: .vigorous, weightKG: 80, duration: 0) == 0)
    }

    /// Everything logged at the end reads as a two-minute session; a finish
    /// tapped at home reads as five hours.
    @Test("Durations that are not the session are caught")
    func durationChecks() {
        #expect(WorkoutEnergy.check(2 * 60) == .tooShort)
        #expect(WorkoutEnergy.check(45 * 60) == .plausible)
        #expect(WorkoutEnergy.check(3 * 3600) == .plausible)
        #expect(WorkoutEnergy.check(5 * 3600) == .unusuallyLong)
    }
}

@Suite("Workout timing")
struct WorkoutTimingTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func session(sets minutes: [Double], finishedAfter: Double? = 90) throws -> WorkoutSession {
        let sets = try minutes.map { try LoggedSet(weightKG: 60, reps: 8, completedAt: start.addingTimeInterval($0 * 60)) }
        return WorkoutSession(
            date: start, dayID: UUID(), dayName: "Push", groups: [.chest],
            entries: [WorkoutEntry(exerciseID: "catalogue.bench.flat", sets: sets)],
            finishedAt: finishedAfter.map { start.addingTimeInterval($0 * 60) }
        )
    }

    @Test("Timed from the first set to the last")
    func firstSetToLast() throws {
        // Started the session at 0, first set at 10, last at 55, finished at 90.
        let window = try #require(WorkoutEnergy.window(for: try session(sets: [10, 30, 55])))
        #expect(window.basis == .loggedSpan)
        #expect(window.start == start.addingTimeInterval(10 * 60))
        #expect(window.duration == 45 * 60)
    }

    /// Everything logged together at the end: a span of seconds says nothing,
    /// so the session's own clock is used, and says so.
    @Test("Sets logged together fall back to start to finish")
    func batchLoggingFallsBack() throws {
        let window = try #require(WorkoutEnergy.window(for: try session(sets: [60, 60.1, 60.2])))
        #expect(window.basis == .startToFinish)
        #expect(window.start == start)
        #expect(window.duration == 90 * 60)
    }

    @Test("Cardio counts from when it began")
    func cardioCountsFromItsStart() throws {
        let run = try CardioEffort(seconds: 20 * 60, completedAt: start.addingTimeInterval(70 * 60))
        var entry = WorkoutEntry(exerciseID: "catalogue.cardio.treadmill")
        entry.cardio = run
        let sets = try session(sets: [10, 30])
        let withCardio = WorkoutSession(
            date: start, dayID: sets.dayID, dayName: "Push", groups: [.chest],
            entries: sets.entries + [entry], finishedAt: sets.finishedAt
        )
        let span = try #require(withCardio.loggedSpan)
        #expect(span.start == start.addingTimeInterval(10 * 60))
        #expect(span.end == start.addingTimeInterval(70 * 60))
    }

    @Test("Nothing logged and not finished is no window")
    func nothingIsNothing() {
        let empty = WorkoutSession(date: start, dayID: UUID(), dayName: "Push", groups: [], entries: [])
        #expect(empty.loggedSpan == nil)
        #expect(WorkoutEnergy.window(for: empty) == nil)
    }
}
