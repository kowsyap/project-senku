import Testing
import SenkuCore
@testable import SenkuUI

/// The few things that can only be checked inside the shipped app.
///
/// Everything about the arithmetic is tested in the packages, on the host, in
/// milliseconds. What those tests cannot see is the app bundle: whether the
/// catalogue's JSON was actually copied into it, and whether the App Group the
/// widgets and the watch all read through is reachable from the real sandbox.
/// Both have broken before, and neither fails until the app is running.
@MainActor
struct SenkuBundleTests {
    @Test func theExerciseCatalogueIsInTheBundle() {
        let catalogue = ExerciseCatalogue.bundled

        #expect(!catalogue.exercises.isEmpty)
        #expect(!catalogue.groups.isEmpty)
        // Cardio is a group with one region and no muscles — the shape the
        // coverage maths depends on.
        #expect(catalogue.groups.contains { !$0.isMuscle })
    }

    @Test func theAppGroupIsReachable() {
        let container = SenkuStorage.shared

        container.set("senku.test", forKey: "senku.test.probe")
        #expect(container.string(forKey: "senku.test.probe") == "senku.test")
        container.removeObject(forKey: "senku.test.probe")
    }

    /// A store reads its own writes through the container, which is the whole
    /// mechanism behind the widgets and the watch.
    @Test func aStoreRoundTripsThroughTheContainer() throws {
        let suite = UserDefaults(suiteName: "senku.tests.\(UUID().uuidString)")!
        let store = WaterStore(defaults: suite)

        store.add(millilitres: 500)
        #expect(WaterStore(defaults: suite).log.totalML(on: .now) == 500)
    }
}
