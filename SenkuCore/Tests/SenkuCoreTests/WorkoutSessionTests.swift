import Foundation
import Testing
@testable import SenkuCore

@Suite struct WorkoutSessionTests {
    private func day() -> SplitDay {
        SplitDay(
            name: "Pull",
            groups: [.back, .bicep],
            exerciseIDs: ["catalogue.row.barbell", "catalogue.curl.barbell"]
        )
    }

    @Test func startsAsAChecklistOfThePlannedExercises() {
        let session = WorkoutSession(startingFrom: day())

        #expect(session.entries.count == 2)
        #expect(session.outstandingCount == 2)
        #expect(session.completedCount == 0)
        #expect(session.isFinished == false)
    }

    /// One set is work, not a finished exercise. Three is.
    @Test func threeSetsFinishAnExercise() throws {
        var session = WorkoutSession(startingFrom: day())
        session.add(try LoggedSet(weightKG: 60, reps: 8), to: "catalogue.row.barbell")

        #expect(session.completedCount == 0)
        #expect(session.outstandingCount == 2)
        #expect(session.entry("catalogue.row.barbell")?.hasAnyWork == true)
        #expect(session.entry("catalogue.row.barbell")?.setProgress == "1/3")

        session.add(try LoggedSet(weightKG: 60, reps: 7), to: "catalogue.row.barbell")
        session.add(try LoggedSet(weightKG: 60, reps: 6), to: "catalogue.row.barbell")

        #expect(session.completedCount == 1)
        #expect(session.outstandingCount == 1)
        #expect(session.entry("catalogue.row.barbell")?.volumeKG == 1260)
    }

    /// The escape hatch: done, without typing anything.
    @Test func tickingOffFinishesAnExerciseWithNoSets() {
        var session = WorkoutSession(startingFrom: day())
        session.setMarkedDone(true, for: "catalogue.curl.barbell")

        #expect(session.completedCount == 1)
        #expect(session.entry("catalogue.curl.barbell")?.sets.isEmpty == true)
        // And it counts as trained, which is the point of the tick.
        #expect(session.performedExerciseIDs.contains("catalogue.curl.barbell"))
    }

    /// Stopping at two sets is a decision; the tick records it without
    /// inventing a third.
    @Test func tickingOffFinishesAPartlyLoggedExercise() throws {
        var session = WorkoutSession(startingFrom: day())
        session.add(try LoggedSet(weightKG: 60, reps: 8), to: "catalogue.row.barbell")
        session.add(try LoggedSet(weightKG: 60, reps: 7), to: "catalogue.row.barbell")
        #expect(session.completedCount == 0)

        session.setMarkedDone(true, for: "catalogue.row.barbell")
        #expect(session.completedCount == 1)
        #expect(session.entry("catalogue.row.barbell")?.sets.count == 2)
    }

    /// Skipping is not the same as not having got to it yet — the checklist is
    /// useless if it cannot tell them apart.
    @Test func skippingClearsSomethingFromTheListWithoutCompletingIt() {
        var session = WorkoutSession(startingFrom: day())
        session.setSkipped(true, for: "catalogue.curl.barbell")

        #expect(session.outstandingCount == 1)
        #expect(session.completedCount == 0)
        #expect(session.entry("catalogue.curl.barbell")?.isDone == false)
    }

    /// Logging into a skipped exercise un-skips it. Changing your mind at the
    /// rack should not need the checklist to be corrected first.
    @Test func loggingUnskips() throws {
        var session = WorkoutSession(startingFrom: day())
        session.setSkipped(true, for: "catalogue.curl.barbell")
        session.add(try LoggedSet(weightKG: 20, reps: 10), to: "catalogue.curl.barbell")

        #expect(session.entry("catalogue.curl.barbell")?.isSkipped == false)
        #expect(session.entry("catalogue.curl.barbell")?.hasAnyWork == true)
    }

    /// The substitution you make when the rack is taken.
    @Test func aSetForAnUnplannedExerciseIsAppended() throws {
        var session = WorkoutSession(startingFrom: day())
        session.add(try LoggedSet(weightKG: 70, reps: 6), to: "catalogue.pullup")

        #expect(session.entries.count == 3)
        #expect(session.entry("catalogue.pullup")?.hasAnyWork == true)
    }

    /// Coverage must be scored on what was done, not what was intended — and a
    /// single set counts, which is why it is `hasAnyWork` and not `isDone`.
    @Test func performedExercisesExcludeTheSkippedAndTheForgotten() throws {
        var session = WorkoutSession(startingFrom: day())
        session.add(try LoggedSet(weightKG: 60, reps: 8), to: "catalogue.row.barbell")
        session.setSkipped(true, for: "catalogue.curl.barbell")

        #expect(session.performedExerciseIDs == ["catalogue.row.barbell"])
    }

    @Test func heaviestSetBreaksTiesOnReps() throws {
        var session = WorkoutSession(startingFrom: day())
        session.add(try LoggedSet(weightKG: 60, reps: 8), to: "catalogue.row.barbell")
        session.add(try LoggedSet(weightKG: 60, reps: 10), to: "catalogue.row.barbell")
        session.add(try LoggedSet(weightKG: 55, reps: 12), to: "catalogue.row.barbell")

        #expect(session.entry("catalogue.row.barbell")?.heaviestSet?.reps == 10)
    }

    @Test func volumeIsWeightTimesReps() throws {
        var session = WorkoutSession(startingFrom: day())
        session.add(try LoggedSet(weightKG: 60, reps: 8), to: "catalogue.row.barbell")
        session.add(try LoggedSet(weightKG: 20, reps: 10), to: "catalogue.curl.barbell")

        #expect(session.volumeKG == 680)
        #expect(session.totalSets == 2)
    }

    @Test func bodyweightSetsAreAllowedAndZeroRepsAreNot() {
        #expect(throws: Never.self) { try LoggedSet(weightKG: 0, reps: 12) }
        #expect(throws: (any Error).self) { try LoggedSet(weightKG: 0, reps: 0) }
        #expect(throws: (any Error).self) { try LoggedSet(weightKG: -1, reps: 5) }
    }
}

@Suite struct TrainingPlanTests {
    @Test func everyTemplateNamesItsDaysAndGroups() {
        for template in SplitTemplate.allCases {
            let plan = template.plan
            #expect(!plan.isEmpty)
            #expect(plan.days.allSatisfy { !$0.name.isEmpty })
            #expect(plan.days.allSatisfy { !$0.groups.isEmpty })
            // Templates carry no exercises: those are the user's to pick.
            #expect(plan.days.allSatisfy { $0.isEmpty })
        }
    }

    /// The one question a plan can answer that a single day cannot.
    @Test func namesTheGroupsThePlanNeverTrains() {
        let plan = TrainingPlan(days: [SplitDay(name: "Push", groups: [.chest, .tricep])])

        #expect(plan.untrainedGroups.contains(.legs))
        #expect(!plan.untrainedGroups.contains(.chest))
    }

    /// Cardio is excluded from the gap report: a lifting plan without it is a
    /// lifting plan, not an incomplete one.
    @Test func aFullTemplateLeavesNoMuscleUntrained() {
        #expect(SplitTemplate.pushPullLegs.plan.untrainedGroups.isEmpty)
        #expect(SplitTemplate.bodyPart.plan.untrainedGroups.isEmpty)
        #expect(!SplitTemplate.pushPullLegs.plan.trainedGroups.contains(.cardio))
    }
}

@Suite struct ContributorTests {
    private let catalogue = ExerciseCatalogue.bundled

    /// The point of the whole thing: a movement filed under one group shows up
    /// under every group it actually trains.
    @Test func anExerciseAppearsUnderEveryGroupItTrains() throws {
        let bench = try #require(catalogue.exercise("catalogue.bench.flat"))

        let chest = MuscleCoverage.contributors(among: [bench], to: .chest, in: catalogue)
        let triceps = MuscleCoverage.contributors(among: [bench], to: .tricep, in: catalogue)

        #expect(chest.count == 1)
        #expect(triceps.count == 1)
        // Filed as chest, and it should read as more chest than triceps.
        #expect(chest[0].fraction > triceps[0].fraction)
    }

    @Test func exercisesThatDoNothingForAGroupAreLeftOut() throws {
        let curl = try #require(catalogue.exercises(in: .bicep).first)

        #expect(MuscleCoverage.contributors(among: [curl], to: .legs, in: catalogue).isEmpty)
    }

    @Test func contributorsAreOrderedByHowMuchTheyCover() {
        let chest = catalogue.exercises(in: .chest)
        let ranked = MuscleCoverage.contributors(among: chest, to: .chest, in: catalogue)

        #expect(ranked.count > 1)
        #expect(zip(ranked, ranked.dropFirst()).allSatisfy { $0.fraction >= $1.fraction })
    }

    /// Cardio is in the catalogue as a group, with exercises and shares that
    /// hold to the same rules as every muscle.
    @Test func cardioIsAGroupButNotAMuscle() {
        #expect(catalogue.workoutGroups.contains(.cardio))
        #expect(WorkoutGroup.cardio.isMuscle == false)
        #expect(WorkoutGroup.chest.isMuscle)
        #expect(!catalogue.exercises(in: .cardio).isEmpty)

        let shares = catalogue.regions(in: .cardio).reduce(0) { $0 + $1.groupShare }
        #expect(abs(shares - 1) < 0.0001)
    }
}

/// Holds — planks, wall sits — measured in seconds rather than reps.
@Suite struct TimedSetTests {
    @Test func aHoldIsStoredInSecondsAndHasNoRepCount() throws {
        let plank = try LoggedSet(weightKG: 0, seconds: 60)

        #expect(plank.isTimed)
        #expect(plank.reps == 0)
        // The whole reason seconds is its own field: sixty seconds must never
        // be read as sixty repetitions.
        #expect(plank.estimatedOneRepMax == nil)
    }

    @Test func aHoldNeedsATimeAndASetNeedsReps() {
        #expect(throws: (any Error).self) { try LoggedSet(weightKG: 0, reps: 0) }
        #expect(throws: (any Error).self) { try LoggedSet(weightKG: 0, seconds: 0) }
        #expect(throws: Never.self) { try LoggedSet(weightKG: 10, seconds: 45) }
    }

    @Test func theRecordForAHoldIsTheLongestOne() throws {
        let book = RecordBook([
            try PersonalRecord(exerciseID: "catalogue.abs.plank", weightKG: 0, seconds: 60),
            try PersonalRecord(exerciseID: "catalogue.abs.plank", weightKG: 0, seconds: 90),
            try PersonalRecord(exerciseID: "catalogue.abs.plank", weightKG: 10, seconds: 90),
        ])
        let entry = book.records(for: "catalogue.abs.plank")

        #expect(entry.isTimed)
        #expect(entry.longestHold?.seconds == 90)
        // Same time, more weight on your back: the better hold.
        #expect(entry.longestHold?.weightKG == 10)
        #expect(entry.best?.seconds == 90)
    }

    @Test func aLongerHoldIsARecordAndAShorterOneIsNot() throws {
        let book = RecordBook([
            try PersonalRecord(exerciseID: "catalogue.abs.plank", weightKG: 0, seconds: 60)
        ])

        #expect(book.wouldBeRecord(exerciseID: "catalogue.abs.plank", weightKG: 0, reps: 0, seconds: 75))
        #expect(!book.wouldBeRecord(exerciseID: "catalogue.abs.plank", weightKG: 0, reps: 0, seconds: 45))
        // Same minute, but weighted.
        #expect(book.wouldBeRecord(exerciseID: "catalogue.abs.plank", weightKG: 5, reps: 0, seconds: 60))
    }

    @Test func theCatalogueMarksTheHolds() throws {
        let catalogue = ExerciseCatalogue.bundled
        #expect(catalogue.exercise("catalogue.abs.plank")?.isTimed == true)
        #expect(catalogue.exercise("catalogue.wallSit")?.isTimed == true)
        #expect(catalogue.exercise("catalogue.bench.flat")?.isTimed == false)
    }
}
