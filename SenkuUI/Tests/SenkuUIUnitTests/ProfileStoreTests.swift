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
        XCTAssertEqual(draft.weightKG, 80, accuracy: 0.001)
        XCTAssertEqual(draft.heightCM, 180, accuracy: 0.001)

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

    func testImperialEditingKeepsMetricAuthoritative() {
        let draft = PlanDraft(unitSystem: .imperial, heightCM: 180, weightKG: 80)

        draft.weightPounds = 200
        XCTAssertEqual(draft.weightKG, 90.718, accuracy: 0.01)

        draft.heightFeet = 6
        draft.heightInches = 0
        XCTAssertEqual(draft.heightCM, 182.88, accuracy: 0.01)
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
