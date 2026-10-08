import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// What Apple Health is sent, decided without HealthKit: the comparison between
/// a log and what has already been written from it.
@Suite struct HealthSyncPlanTests {
    private let since = Date(timeIntervalSince1970: 1_800_000_000)

    private func item(_ minutesAfter: Double, _ fingerprint: String = "a", id: UUID = UUID()) -> HealthSyncPlan.Item {
        HealthSyncPlan.Item(id: id, date: since.addingTimeInterval(minutesAfter * 60), fingerprint: fingerprint)
    }

    /// Turning a kind on is about from now: a year of history is not copied in.
    @Test func entriesBeforeSyncingBeganStayOut() {
        let before = item(-30)
        let after = item(30)
        let plan = HealthSyncPlan.diff([before, after], since: since, written: [:])
        #expect(plan.write == [after.id])
        #expect(plan.remove.isEmpty)
    }

    @Test func aWrittenEntryIsNotWrittenAgain() {
        let glass = item(5)
        let plan = HealthSyncPlan.diff([glass], since: since, written: [glass.id: "a"])
        #expect(plan.write.isEmpty)
        #expect(plan.remove.isEmpty)
    }

    @Test func aDeletedEntryIsTakenBack() {
        let kept = item(5)
        let deleted = item(10)
        let plan = HealthSyncPlan.diff([kept], since: since, written: [kept.id: "a", deleted.id: "a"])
        #expect(plan.write.isEmpty)
        #expect(plan.remove == [deleted.id])
    }

    /// An edit replaces: the old samples out, the new ones in — so changing
    /// a meal's fat to nothing does not leave the old fat in Health.
    @Test func anEditedEntryIsReplaced() {
        let meal = item(5, "after")
        let plan = HealthSyncPlan.diff([meal], since: since, written: [meal.id: "before"])
        #expect(plan.remove == [meal.id])
        #expect(plan.write == [meal.id])
    }

    /// Already written, then edited to a time before the switch: still
    /// followed, rather than leaving its old version stranded in Health.
    @Test func anEditMovedEarlierIsStillFollowed() {
        let meal = item(-120, "moved")
        let plan = HealthSyncPlan.diff([meal], since: since, written: [meal.id: "original"])
        #expect(plan.write == [meal.id])
        #expect(plan.remove == [meal.id])
    }

    /// An undone delete puts the same entry back with the same id, and it is
    /// written again — not as a second copy, since the first was removed.
    @Test func anUndoneDeleteIsWrittenBack() {
        let glass = item(5)
        #expect(HealthSyncPlan.diff([], since: since, written: [glass.id: "a"]).remove == [glass.id])
        #expect(HealthSyncPlan.diff([glass], since: since, written: [:]).write == [glass.id])
    }

    @Test func aFoodEditChangesItsFingerprint() throws {
        let entry = try IntakeEntry(proteinG: 30, carbsG: 40, fatG: 10)
        var edited = entry
        edited.fatG = 0
        #expect(HealthSyncPlan.item(entry).fingerprint != HealthSyncPlan.item(edited).fingerprint)
        #expect(HealthSyncPlan.item(entry).id == HealthSyncPlan.item(edited).id)
    }

    /// Only weigh-ins measured here: a backup's are copies of measurements
    /// already recorded, and the one seeded from the profile is not a
    /// measurement at all.
    @Test func onlyManualWeighInsAreWritten() throws {
        #expect(HealthSyncPlan.isWritable(try WeighIn(date: since, weightKG: 80, source: .manual)))
        #expect(!HealthSyncPlan.isWritable(try WeighIn(date: since, weightKG: 80, source: .imported)))
    }

    /// Never in a backup, and off until switched on.
    @Test func settingsStartOff() {
        let settings = HealthSettings()
        #expect(HealthKind.allCases.allSatisfy { !settings.isOn($0) })
        #expect(!SettingsBackup.keys.contains { $0.hasPrefix("senku.health") })
    }

    /// The first version stored water alone as a flag and a date; a phone that
    /// switched water on then still has it on.
    @Test func theFirstVersionsSettingsStillRead() throws {
        let json = #"{"water":true,"waterSince":800000000}"#
        let settings = try JSONDecoder().decode(HealthSettings.self, from: Data(json.utf8))
        #expect(settings.isOn(.water))
        #expect(!settings.isOn(.food))

        let roundTrip = try JSONDecoder().decode(HealthSettings.self, from: JSONEncoder().encode(settings))
        #expect(roundTrip == settings)
    }
}
