import XCTest
import SenkuCore
@testable import SenkuUI

final class ProfileStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "senku.tests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeProfile(bodyFat: Double? = 18) throws -> ProfileStore.Profile {
        ProfileStore.Profile(
            metrics: try BodyMetrics(
                sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: bodyFat
            ),
            activityLevel: .moderate,
            goal: .moderateCut,
            formula: .automatic,
            unitSystem: .metric
        )
    }

    func testSavedProfileSurvivesANewStoreOverTheSameStorage() throws {
        let store = ProfileStore(defaults: defaults)
        XCTAssertFalse(store.hasProfile)

        let profile = try makeProfile()
        store.save(profile)

        // A second store stands in for the next app launch.
        let reloaded = ProfileStore(defaults: defaults)
        let restored = try XCTUnwrap(reloaded.profile)

        XCTAssertEqual(restored.metrics, profile.metrics)
        XCTAssertEqual(restored.activityLevel, .moderate)
        XCTAssertEqual(restored.goal, .moderateCut)
        XCTAssertEqual(restored.formula, .automatic)
        XCTAssertEqual(restored.unitSystem, .metric)
    }

    func testAbsentBodyFatSurvivesTheRoundTrip() throws {
        // The nil case matters: it is what decides between Mifflin-St Jeor and
        // Katch-McArdle, so losing it in storage would silently change results.
        let store = ProfileStore(defaults: defaults)
        store.save(try makeProfile(bodyFat: nil))

        let restored = try XCTUnwrap(ProfileStore(defaults: defaults).profile)
        XCTAssertNil(restored.metrics.bodyFatPercentage)
        XCTAssertEqual(restored.plan.energy.formulaUsed, .mifflinStJeor)
    }

    func testSavingStampsTheUpdateTime() throws {
        let store = ProfileStore(defaults: defaults)
        let before = Date.now
        store.save(try makeProfile())
        let saved = try XCTUnwrap(store.profile)

        XCTAssertGreaterThanOrEqual(saved.updatedAt, before)
        XCTAssertLessThanOrEqual(saved.updatedAt, .now)
    }

    func testClearRemovesTheProfileEverywhere() throws {
        let store = ProfileStore(defaults: defaults)
        store.save(try makeProfile())
        XCTAssertTrue(store.hasProfile)

        store.clear()

        XCTAssertFalse(store.hasProfile)
        XCTAssertFalse(ProfileStore(defaults: defaults).hasProfile)
    }

    func testUnreadableStorageIsDroppedRatherThanCrashing() throws {
        defaults.set(Data("not a profile".utf8), forKey: "senku.profile.v1")

        // A cached convenience is not worth dying for.
        XCTAssertNil(ProfileStore(defaults: defaults).profile)
    }

    func testDraftSeedsFromAProfileAndSnapshotsBackUnchanged() throws {
        let profile = try makeProfile()
        let draft = PlanDraft(profile: profile)

        XCTAssertTrue(draft.usesMeasuredBodyFat)
        XCTAssertEqual(try XCTUnwrap(draft.weightKG), 80, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(draft.heightCM), 180, accuracy: 0.001)

        let snapshot = try XCTUnwrap(draft.profileSnapshot)
        XCTAssertEqual(snapshot.metrics, profile.metrics)
        XCTAssertEqual(snapshot.goal, profile.goal)
    }

    func testDraftWithoutMeasuredBodyFatSnapshotsAsNil() throws {
        let draft = PlanDraft(profile: try makeProfile(bodyFat: nil))
        XCTAssertFalse(draft.usesMeasuredBodyFat)

        let snapshot = try XCTUnwrap(draft.profileSnapshot)
        XCTAssertNil(snapshot.metrics.bodyFatPercentage)
    }

    func testImperialEditingKeepsMetricAuthoritative() throws {
        let draft = PlanDraft(unitSystem: .imperial, heightCM: 180, weightKG: 80)

        draft.weightPounds = 200
        XCTAssertEqual(try XCTUnwrap(draft.weightKG), 90.718, accuracy: 0.01)

        draft.heightFeet = 6
        draft.heightInches = 0
        XCTAssertEqual(try XCTUnwrap(draft.heightCM), 182.88, accuracy: 0.01)
    }

    func testAFreshDraftIsEmptyAndSaysWhatItNeeds() {
        // The calculator opens blank on purpose: a pre-filled age produces a
        // plausible plan for a person who never entered anything.
        let draft = PlanDraft()
        XCTAssertNil(draft.age)
        XCTAssertNil(draft.heightCM)
        XCTAssertNil(draft.weightKG)
        XCTAssertFalse(draft.isComplete)
        XCTAssertNil(draft.plan)
        XCTAssertEqual(draft.missingFields, ["Age", "Height", "Weight"])

        let message = draft.validationMessage
        XCTAssertNotNil(message)
        for field in ["Age", "Height", "Weight"] {
            XCTAssertTrue(message?.contains(field) == true, "should name \(field): \(message ?? "")")
        }
    }

    func testAPartlyFilledDraftNamesOnlyWhatIsStillMissing() {
        let draft = PlanDraft(age: 30, heightCM: 175)
        XCTAssertEqual(draft.missingFields, ["Weight"])
        XCTAssertFalse(draft.isComplete)
        XCTAssertTrue(draft.validationMessage?.contains("Weight") == true)
        XCTAssertFalse(draft.validationMessage?.contains("Age") == true)

        draft.weightKG = 75
        XCTAssertTrue(draft.isComplete)
        XCTAssertNil(draft.validationMessage)
        XCTAssertNotNil(draft.plan)
    }

    func testClearingAFieldUnanswersItRatherThanZeroingIt() {
        let draft = PlanDraft(age: 30, heightCM: 175, weightKG: 75)
        XCTAssertNotNil(draft.plan)

        draft.weightKG = nil
        XCTAssertNil(draft.plan, "An empty field is not a weight of zero")
        XCTAssertEqual(draft.missingFields, ["Weight"])
    }

    func testAnEmptyDraftStaysEmptyAcrossAUnitSwitch() {
        let draft = PlanDraft(unitSystem: .metric)
        XCTAssertNil(draft.weightPounds)
        XCTAssertNil(draft.heightFeet)
        XCTAssertNil(draft.heightInches)

        draft.unitSystem = .imperial
        XCTAssertNil(draft.weightKG, "Switching units must not invent a zero")
        XCTAssertNil(draft.heightCM)
    }

    func testInvalidInputYieldsNoPlanAndAnExplanation() {
        let draft = PlanDraft(age: 30, heightCM: 175, weightKG: 75)
        XCTAssertNotNil(draft.plan)
        XCTAssertNil(draft.validationMessage)

        draft.age = 5
        XCTAssertNil(draft.plan)
        XCTAssertNotNil(draft.validationMessage)
        XCTAssertNil(draft.profileSnapshot)
    }
}

/// The App Group move is the kind of change that looks like data loss if the
/// migration is missing: the profile is still in `.standard`, just nowhere
/// anything reads any more.
final class SharedStorageTests: XCTestCase {
    func testAProfileSavedBeforeTheAppGroupIsStillFoundAfterIt() throws {
        let legacy = UserDefaults(suiteName: "senku.test.legacy")!
        let group = UserDefaults(suiteName: "senku.test.group")!
        defer {
            legacy.removePersistentDomain(forName: "senku.test.legacy")
            group.removePersistentDomain(forName: "senku.test.group")
        }
        group.removeObject(forKey: ProfileStore.storageKey)

        let metrics = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 80)
        let profile = ProfileStore.Profile(
            metrics: metrics, activityLevel: .moderate, goal: .maintain,
            formula: .automatic, unitSystem: .metric
        )
        ProfileStore(defaults: legacy).save(profile)
        XCTAssertNotNil(legacy.data(forKey: ProfileStore.storageKey))

        // Standing in for SenkuStorage's one-time move.
        let carried = try XCTUnwrap(legacy.data(forKey: ProfileStore.storageKey))
        group.set(carried, forKey: ProfileStore.storageKey)

        XCTAssertEqual(ProfileStore(defaults: group).profile?.metrics, metrics)
    }
}

/// The fields added after the first release: a name, and a goal weight.
final class ProfileIdentityTests: XCTestCase {
    /// A profile written before either field existed has to keep opening.
    /// Both are optional for exactly this reason, and this is the test that
    /// says so — the alternative is a decode failure that silently drops
    /// someone's saved numbers.
    func testAProfileSavedWithoutANameStillDecodes() throws {
        let json = """
        {
          "metrics": { "sex": "male", "age": 30, "heightCM": 180, "weightKG": 80 },
          "activityLevel": "moderate",
          "goal": "maintain",
          "formula": "automatic",
          "unitSystem": "metric",
          "updatedAt": 750000000
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(ProfileStore.Profile.self, from: json)

        XCTAssertNil(profile.name)
        XCTAssertNil(profile.goalWeightKG)
        XCTAssertEqual(profile.metrics.weightKG, 80)
    }

    func testADraftKeepsTheNameAndGoalWeightThroughASaveAndAnEdit() throws {
        let draft = PlanDraft(
            name: "  Kowsyap  ",
            age: 30, heightCM: 180, weightKG: 80,
            goal: .moderateCut,
            goalWeightKG: 72
        )

        let saved = try XCTUnwrap(draft.profileSnapshot)
        // Trimmed on the way in, so a stray space never becomes the name.
        XCTAssertEqual(saved.name, "Kowsyap")
        XCTAssertEqual(saved.goalWeightKG, 72)

        let reopened = PlanDraft(profile: saved)
        XCTAssertEqual(reopened.name, "Kowsyap")
        XCTAssertEqual(reopened.goalWeightKG, 72)
    }

    /// A name of nothing but whitespace is no name at all.
    func testABlankNameIsNotSaved() throws {
        let draft = PlanDraft(name: "   ", age: 30, heightCM: 180, weightKG: 80)
        XCTAssertNil(try XCTUnwrap(draft.profileSnapshot).name)
    }

    /// The signature behind the Calculate button: it must notice a changed
    /// input, and must not fire on a change that the plan does not depend on.
    func testInputsChangeWithTheNumbersButNotWithTheUnitsOrTheName() {
        let draft = PlanDraft(age: 30, heightCM: 180, weightKG: 80)
        let before = draft.inputs

        draft.unitSystem = .imperial
        draft.name = "Someone"
        draft.goalWeightKG = 72
        XCTAssertEqual(draft.inputs, before)

        draft.weightKG = 79.5
        XCTAssertNotEqual(draft.inputs, before)
    }
}

/// The weight log's storage. The maths is tested in SenkuCore; this is about
/// what survives a round trip and what the store hands to it.
final class WeightLogStoreTests: XCTestCase {
    private func store() -> WeightLogStore {
        let defaults = UserDefaults(suiteName: "senku.test.weight")!
        defaults.removePersistentDomain(forName: "senku.test.weight")
        return WeightLogStore(defaults: defaults)
    }

    func testWeighInsSurviveAReload() throws {
        let defaults = UserDefaults(suiteName: "senku.test.weight.reload")!
        defaults.removePersistentDomain(forName: "senku.test.weight.reload")
        defer { defaults.removePersistentDomain(forName: "senku.test.weight.reload") }

        let first = WeightLogStore(defaults: defaults)
        first.add(try WeighIn(date: Date(timeIntervalSince1970: 1_700_000_000), weightKG: 80))
        first.add(try WeighIn(date: Date(timeIntervalSince1970: 1_700_086_400), weightKG: 79.5))

        XCTAssertEqual(WeightLogStore(defaults: defaults).weighIns.count, 2)
    }

    func testTheNewestWeighInComesFirst() throws {
        let log = store()
        let old = try WeighIn(date: Date(timeIntervalSince1970: 1_700_000_000), weightKG: 80)
        let new = try WeighIn(date: Date(timeIntervalSince1970: 1_700_600_000), weightKG: 79)

        log.add(old)
        log.add(new)

        XCTAssertEqual(log.weighIns.first?.id, new.id)
    }

    func testDeletingRemovesOnlyThatReading() throws {
        let log = store()
        let keep = try WeighIn(date: Date(timeIntervalSince1970: 1_700_000_000), weightKG: 80)
        let drop = try WeighIn(date: Date(timeIntervalSince1970: 1_700_600_000), weightKG: 79)
        log.add(keep)
        log.add(drop)

        log.delete(drop)

        XCTAssertEqual(log.weighIns.map(\.id), [keep.id])
    }

    /// The store hands the series everything it has, so the trend it reports is
    /// the trend of the whole log rather than of whatever is on screen.
    func testTheSeriesSeesEveryReading() throws {
        let log = store()
        for day in 0 ..< 5 {
            log.add(
                try WeighIn(
                    date: Date(timeIntervalSince1970: 1_700_000_000 + Double(day) * 86_400),
                    weightKG: 80 - Double(day) * 0.2
                )
            )
        }

        XCTAssertEqual(log.series.dailyValues.count, 5)
        XCTAssertNotNil(log.series.trendKG)
    }
}

extension WeightLogStoreTests {
    private func profile() throws -> ProfileStore.Profile {
        ProfileStore.Profile(
            metrics: try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 80),
            activityLevel: .moderate,
            goal: .maintain,
            formula: .automatic,
            unitSystem: .metric,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func testAnEmptyLogStartsFromTheProfileWeight() throws {
        let defaults = UserDefaults(suiteName: "senku.test.weight.seed")!
        defaults.removePersistentDomain(forName: "senku.test.weight.seed")
        defer { defaults.removePersistentDomain(forName: "senku.test.weight.seed") }

        let log = WeightLogStore(defaults: defaults)
        XCTAssertTrue(log.seedFromProfileIfNeeded(try profile()))

        XCTAssertEqual(log.weighIns.count, 1)
        XCTAssertEqual(log.weighIns.first?.weightKG, 80)
        // Carried over, not measured here, and recorded as such.
        XCTAssertEqual(log.weighIns.first?.source, .imported)
    }

    func testTheProfileWeightIsSeededOnlyOnce() throws {
        let defaults = UserDefaults(suiteName: "senku.test.weight.seed.once")!
        defaults.removePersistentDomain(forName: "senku.test.weight.seed.once")
        defer { defaults.removePersistentDomain(forName: "senku.test.weight.seed.once") }

        let log = WeightLogStore(defaults: defaults)
        log.seedFromProfileIfNeeded(try profile())
        log.delete(try XCTUnwrap(log.weighIns.first))

        // Deleting the seed means you did not want it. Asking again on the next
        // appearance would be the app arguing with you.
        XCTAssertFalse(log.seedFromProfileIfNeeded(try profile()))
        XCTAssertTrue(log.weighIns.isEmpty)
    }

    func testSeedingDoesNothingWhenReadingsExist() throws {
        let log = store()
        log.add(try WeighIn(date: Date(timeIntervalSince1970: 1_700_600_000), weightKG: 77))

        XCTAssertFalse(log.seedFromProfileIfNeeded(try profile()))
        XCTAssertEqual(log.weighIns.count, 1)
    }
}

/// The record store's own rules — the maths lives in SenkuCore.
final class RecordStoreTests: XCTestCase {
    private func store(_ suite: String = "senku.test.records") -> RecordStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return RecordStore(defaults: defaults)
    }

    func testABetterSetIsRecordedAndAWorseOneIsNot() throws {
        let records = store()

        XCTAssertNotNil(
            records.offer(exerciseID: "catalogue.bench.flat", weightKG: 100, reps: 5, setID: UUID())
        )
        // Lighter and easier: nothing to record.
        XCTAssertNil(
            records.offer(exerciseID: "catalogue.bench.flat", weightKG: 90, reps: 3, setID: UUID())
        )
        XCTAssertEqual(records.records.count, 1)
    }

    /// The rule the PR page exists for: beating a lift adds to the history, it
    /// does not overwrite it.
    func testBeatingARecordKeepsTheOldOne() throws {
        let records = store()
        records.offer(exerciseID: "catalogue.bench.flat", weightKG: 100, reps: 5, setID: UUID())
        records.offer(exerciseID: "catalogue.bench.flat", weightKG: 110, reps: 3, setID: UUID())

        XCTAssertEqual(records.records.count, 2)
        XCTAssertEqual(records.book.records(for: "catalogue.bench.flat").heaviest?.weightKG, 110)
    }

    func testRecordsSurviveAReload() throws {
        let suite = "senku.test.records.reload"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = RecordStore(defaults: defaults)
        first.add(try PersonalRecord(exerciseID: "catalogue.squat.back", weightKG: 140, reps: 1))

        XCTAssertEqual(RecordStore(defaults: defaults).records.count, 1)
    }

    /// Open question 4, answered: deleting a session you mislogged is not the
    /// same as un-lifting the weight.
    func testDeletingTheSetBehindARecordLeavesTheRecordAsManual() throws {
        let records = store()
        let setID = UUID()
        records.offer(exerciseID: "catalogue.bench.flat", weightKG: 100, reps: 5, setID: setID)

        records.detachRecords(fromSets: [setID])

        XCTAssertEqual(records.records.count, 1)
        XCTAssertEqual(records.records.first?.source, .manual)
    }

    func testDeletingARecordRemovesOnlyThatOne() throws {
        let records = store()
        let keep = try PersonalRecord(exerciseID: "catalogue.bench.flat", weightKG: 100, reps: 5)
        let drop = try PersonalRecord(exerciseID: "catalogue.squat.back", weightKG: 140, reps: 1)
        records.add(keep)
        records.add(drop)

        records.delete(drop)

        XCTAssertEqual(records.records.map(\.id), [keep.id])
    }
}

extension RecordStoreTests {
    func testEditingARecordKeepsItsPlaceAndItsIdentity() throws {
        let records = store("senku.test.records.edit")
        let original = try PersonalRecord(
            exerciseID: "catalogue.bench.flat",
            weightKG: 100,
            reps: 5,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        records.add(original)

        // The row you fix is the row you mistyped: same id, new figure.
        let corrected = try PersonalRecord(
            id: original.id,
            exerciseID: original.exerciseID,
            weightKG: 105,
            reps: 5,
            date: original.date,
            source: original.source
        )
        records.update(corrected)

        XCTAssertEqual(records.records.count, 1)
        XCTAssertEqual(records.records.first?.id, original.id)
        XCTAssertEqual(records.records.first?.weightKG, 105)
    }

    func testEditingSomethingThatIsNotThereChangesNothing() throws {
        let records = store("senku.test.records.edit.missing")
        records.add(try PersonalRecord(exerciseID: "catalogue.bench.flat", weightKG: 100, reps: 5))

        records.update(try PersonalRecord(exerciseID: "catalogue.bench.flat", weightKG: 999, reps: 1))

        XCTAssertEqual(records.records.count, 1)
        XCTAssertEqual(records.records.first?.weightKG, 100)
    }

    func testDeletingAnExerciseRemovesOnlyItsOwnRecords() throws {
        let records = store("senku.test.records.deleteAll")
        records.add(try PersonalRecord(exerciseID: "catalogue.bench.flat", weightKG: 100, reps: 5))
        records.add(try PersonalRecord(exerciseID: "catalogue.bench.flat", weightKG: 110, reps: 3))
        let squat = try PersonalRecord(exerciseID: "catalogue.squat.back", weightKG: 140, reps: 1)
        records.add(squat)

        records.deleteAll(forExercise: "catalogue.bench.flat")

        XCTAssertEqual(records.records.map(\.id), [squat.id])
    }
}
