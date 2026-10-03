import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// A backup restored onto an empty device gives back what was taken — for the
/// parts added most recently, which are the ones most likely to be forgotten.
@MainActor
@Suite struct BackupRoundTripTests {
    @MainActor
    private struct Device {
        let suite = UserDefaults(suiteName: "senku.roundtrip.\(UUID().uuidString)")!
        lazy var profiles = ProfileStore(defaults: suite)
        lazy var weights = WeightLogStore(defaults: suite)
        lazy var records = RecordStore(defaults: suite)
        lazy var library = ExerciseLibrary(defaults: suite)
        lazy var plans = TrainingPlanStore(defaults: suite)
        lazy var workouts = WorkoutStore(defaults: suite)
        lazy var cardioRecords = CardioRecordStore(defaults: suite)
        lazy var cardioPlans = CardioProtocolStore(defaults: suite)
        lazy var anime = AnimeStore(defaults: suite)
        lazy var water = WaterStore(defaults: suite)
        lazy var intake = IntakeStore(defaults: suite)
        lazy var dues = DueDateStore(defaults: suite)
        lazy var watchlist = WatchlistName(defaults: suite)

        mutating func backup() throws -> SenkuImportDocument {
            let document = SenkuImportDocument.snapshot(
                profile: profiles.profile, weights: weights, records: records,
                library: library, plans: plans, workouts: workouts,
                cardioRecords: cardioRecords, cardioPlans: cardioPlans,
                anime: anime, water: water, intake: intake,
                dueDates: dues, watchlist: watchlist, settingsFrom: suite
            )
            // Through the file format, not just the in-memory value.
            return try SenkuImportDocument.decode(try document.encoded())
        }

        @discardableResult
        mutating func restore(_ document: SenkuImportDocument) -> ImportSummary {
            SenkuImporter.apply(
                document, profiles: profiles, weights: weights, records: records,
                library: library, plans: plans, workouts: workouts,
                cardioRecords: cardioRecords, cardioPlans: cardioPlans,
                anime: anime, water: water, intake: intake,
                dueDates: dues, watchlist: watchlist, settingsTo: suite
            )
        }
    }

    @Test func duesComeBackWithTheirHistory() throws {
        var old = Device()
        var amex = DueItem(title: "Amex", category: "Card", amount: 1200, firstDue: .now, remindDaysBefore: [3, 0])
        amex.markDone()
        old.dues.save(amex)

        var new = Device()
        let summary = new.restore(try old.backup())

        #expect(summary.dueDatesAdded == 1)
        let restored = try #require(new.dues.items.first)
        // Field by field: the file keeps timestamps to the second, so the
        // fraction a live `Date` carries does not survive — as for every
        // other date in a backup.
        #expect(restored.id == amex.id)
        #expect(restored.title == "Amex" && restored.category == "Card" && restored.amount == 1200)
        #expect(restored.repeats == .months && restored.every == 1)
        #expect(restored.doneThrough == amex.doneThrough)
        #expect(restored.nextOpen() == amex.nextOpen())
        #expect(restored.history.count == 1)
        #expect(restored.history.first?.amount == 1200)
        #expect(restored.remindDaysBefore == [3, 0])
    }

    /// The bug this caught: the days were copied one by one and the target
    /// was left behind at 3×10.
    @Test func theRepTargetComesBackWithThePlan() throws {
        var old = Device()
        old.plans.adopt(.pushPullLegs)
        old.plans.setTarget(RepTarget(sets: 4, reps: 8))

        var new = Device()
        new.restore(try old.backup())

        #expect(new.plans.plan.target == RepTarget(sets: 4, reps: 8))
        #expect(new.plans.days.count == 3)
    }

    @Test func theWatchlistNameComesBack() throws {
        var old = Device()
        old.watchlist.name = "K-dramas"

        var new = Device()
        new.restore(try old.backup())

        #expect(new.watchlist.title == "K-dramas")
    }

    /// A backup from before the name existed leaves the current one alone.
    @Test func anOlderBackupKeepsTheCurrentName() throws {
        var new = Device()
        new.watchlist.name = "Anime"
        new.restore(SenkuImportDocument())
        #expect(new.watchlist.title == "Anime")
    }

    @Test func settingsComeBack() throws {
        var old = Device()
        var water = WaterStore.Settings()
        water.takesCreatine = true
        water.reminderIntervalMinutes = 90
        old.suite.set(try JSONEncoder().encode(water), forKey: "senku.water.settings.v1")
        old.suite.set(["food", "water"], forKey: "senku.tabs.visible.v2")
        old.suite.set("imperial", forKey: "senku.plates.unit.v1")
        old.suite.set(true, forKey: "senku.weightReminder.v1")

        var new = Device()
        let summary = new.restore(try old.backup())

        #expect(summary.settingsRestored)
        #expect(new.suite.stringArray(forKey: "senku.tabs.visible.v2") == ["food", "water"])
        #expect(new.suite.string(forKey: "senku.plates.unit.v1") == "imperial")
        #expect(new.suite.bool(forKey: "senku.weightReminder.v1"))
        #expect(WaterStore(defaults: new.suite).settings.reminderIntervalMinutes == 90)
        #expect(TabLayout(defaults: new.suite).chosen == [.food, .water])
    }

    /// Only the listed keys: a hand-edited file cannot set anything else.
    @Test func aBackupCannotWriteKeysOffTheList() {
        let suite = UserDefaults(suiteName: "senku.roundtrip.\(UUID().uuidString)")!
        let sneaky = SettingsBackup(values: ["senku.profile.v1": .string("nope")])
        #expect(sneaky.apply(to: suite) == false)
        #expect(suite.object(forKey: "senku.profile.v1") == nil)
    }

    /// Settings never changed are not carried, so restoring does not overwrite
    /// the other device's choice with a default.
    @Test func untouchedSettingsAreNotCarried() {
        let suite = UserDefaults(suiteName: "senku.roundtrip.\(UUID().uuidString)")!
        #expect(SettingsBackup.capture(from: suite).values.isEmpty)
    }

    @Test func anOlderExportChoiceStillLoads() throws {
        // Saved before Dues existed, with water switched off.
        let old = #"{"profile":true,"weight":true,"records":true,"plan":true,"workouts":true,"water":false,"food":true,"anime":true,"charts":true,"backup":true}"#
        let selection = try JSONDecoder().decode(ReportSelection.self, from: Data(old.utf8))
        #expect(selection.water == false)
        #expect(selection.dues == true)
    }
}
