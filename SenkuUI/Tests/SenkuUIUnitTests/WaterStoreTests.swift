import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

@MainActor
@Suite struct WaterStoreTests {
    private func store(_ name: String = UUID().uuidString) -> WaterStore {
        WaterStore(defaults: UserDefaults(suiteName: name)!)
    }

    @Test func tickingCreatineTodayMakesAStreakOfOne() {
        let store = store()
        #expect(store.creatineStreak == 0)

        store.setCreatine(true)
        #expect(store.tookCreatine())
        #expect(store.creatineStreak == 1)

        store.setCreatine(false)
        #expect(!store.tookCreatine())
        #expect(store.creatineStreak == 0)
    }

    /// Not having ticked today must not read as a broken streak: it is often
    /// only mid-afternoon.
    @Test func yesterdayAloneIsStillAStreak() {
        let store = store()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!

        store.setCreatine(true, on: yesterday)
        #expect(!store.tookCreatine())
        #expect(store.creatineStreak == 1)
    }

    @Test func aGapEndsTheStreak() {
        let store = store()
        for offset in [0, 1, 2, 4] {
            store.setCreatine(true, on: Calendar.current.date(byAdding: .day, value: -offset, to: .now)!)
        }

        #expect(store.creatineStreak == 3)
    }

    @Test func creatineSurvivesReloadingTheStore() {
        let name = UUID().uuidString
        let first = WaterStore(defaults: UserDefaults(suiteName: name)!)
        first.setCreatine(true)

        let second = WaterStore(defaults: UserDefaults(suiteName: name)!)
        #expect(second.tookCreatine())
        #expect(second.creatineStreak == 1)
    }

    /// The other half of the switch: the goal grows by half a litre.
    @Test func takingCreatineRaisesTheTarget() {
        let store = store()
        let before = store.goal(profile: nil, workouts: nil)
        #expect(before.creatineBonusML == 0)

        store.update { $0.takesCreatine = true }
        let after = store.goal(profile: nil, workouts: nil)

        #expect(after.creatineBonusML == 500)
        #expect(after.totalML == before.totalML + 500)
        #expect(after.explanation.contains("+500 creatine"))
    }
}

@MainActor
@Suite struct WaterContainerMigrationTests {
    /// A fourth container could be added before the row was capped, and the
    /// settings screen now has no way to remove one.
    @Test func afourthContainerIsTrimmedOnLoad() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!

        let first = WaterStore(defaults: defaults)
        first.update {
            $0.containers.append(WaterContainer(name: "Flask", millilitres: 1000))
        }
        #expect(first.settings.containers.count == 4)

        let second = WaterStore(defaults: defaults)
        #expect(second.settings.containers.count == 3)
        #expect(!second.settings.containers.contains { $0.name == "Flask" })
    }

    @Test func aMissingContainerIsPutBack() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!

        let first = WaterStore(defaults: defaults)
        first.update { $0.containers.removeLast() }

        let second = WaterStore(defaults: defaults)
        #expect(second.settings.containers.count == 3)
    }

    /// Renamed in place: nobody chose "Large bottle".
    @Test func theOldThirdContainerBecomesAJug() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!

        let first = WaterStore(defaults: defaults)
        first.update { $0.containers[2].name = "Large bottle" }

        let second = WaterStore(defaults: defaults)
        #expect(second.settings.containers[2].name == "Jug")
    }
}
