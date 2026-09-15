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
