import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// `docs/import-example.json` is the full format, one of everything: every
/// section, every field. It has to import whole, and every key in it has to be
/// one the app reads — a key the decoder skips would be a field documented
/// that does nothing.
@MainActor
@Suite struct ImportExampleTests {
    private static let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // SenkuUIUnitTests
        .deletingLastPathComponent()      // Tests
        .deletingLastPathComponent()      // SenkuUI
        .deletingLastPathComponent()      // the repo
        .appendingPathComponent("docs/import-example.json")

    /// The app hands out its own copy as "Sample File": it has to be this one.
    @Test func theAppCarriesTheSameFile() throws {
        let bundled = try #require(SampleFile.url)
        #expect(try Data(contentsOf: bundled) == Data(contentsOf: Self.url),
                "Copy docs/import-example.json to SenkuUI/Sources/SenkuUI/Resources/")
    }

    @Test func everySectionImportsOnce() throws {
        let suite = UserDefaults(suiteName: "senku.example.\(UUID().uuidString)")!
        let library = ExerciseLibrary(defaults: suite)
        let plans = TrainingPlanStore(defaults: suite)
        let profiles = ProfileStore(defaults: suite)
        let anime = AnimeStore(defaults: suite)
        let intake = IntakeStore(defaults: suite)
        let expenses = MoneyStore(.expenses, defaults: suite)
        let income = MoneyStore(.income, defaults: suite)
        let dues = DueDateStore(defaults: suite)

        let document = try SenkuImportDocument.decode(Data(contentsOf: Self.url))
        let summary = SenkuImporter.apply(
            document, profiles: profiles, weights: WeightLogStore(defaults: suite),
            records: RecordStore(defaults: suite), library: library, plans: plans,
            workouts: WorkoutStore(defaults: suite), cardioRecords: CardioRecordStore(defaults: suite),
            cardioPlans: CardioProtocolStore(defaults: suite), anime: anime,
            water: WaterStore(defaults: suite), intake: intake, dueDates: dues,
            expenses: expenses, income: income, settingsTo: suite
        )

        #expect(summary.problems.isEmpty, "\(summary.problems)")
        #expect(profiles.profile?.name == "Maya")
        #expect(summary.weighInsAdded == 1)
        #expect(library.custom.count == 1)
        #expect(summary.recordsAdded == 1)
        #expect(plans.days.count == 1 && plans.days[0].exerciseIDs.count == 3)
        #expect(summary.workoutsAdded == 1)
        #expect(summary.cardioAdded == 2)            // one record, one plan
        #expect(summary.animeAdded == 1 && anime.screens.count >= 1)
        #expect(summary.dueDatesAdded == 1)
        #expect(summary.expensesAdded == 1 && expenses.customCategories == ["Gym gear"])
        #expect(summary.incomeAdded == 1)
        #expect(summary.waterAdded == 1)
        #expect(summary.mealsAdded == 1)
        #expect(intake.favourites.contains { $0.name == "Protein shake" })   // beside the three starters
        #expect(summary.settingsRestored)
        #expect(document.settings?.values.count == SettingsBackup.keys.count)
    }

    /// Read in and written back out, the file keeps every key it had — and
    /// gains none, so nothing the app could import is left out of it.
    @Test func everyKeyIsOneTheAppReads() throws {
        let original = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.url))
        let document = try SenkuImportDocument.decode(Data(contentsOf: Self.url))
        let written = try JSONSerialization.jsonObject(with: document.encoded())

        var ignored: [String] = []
        var missing: [String] = []
        compare(original, written, path: "", ignored: &ignored, missing: &missing)
        #expect(ignored.isEmpty, "Keys the app does not read: \(ignored)")
        #expect(missing.isEmpty, "Fields the example leaves out: \(missing)")
    }

    private func compare(_ a: Any, _ b: Any, path: String, ignored: inout [String], missing: inout [String]) {
        if let a = a as? [String: Any], let b = b as? [String: Any] {
            for key in a.keys where b[key] == nil { ignored.append(path + "." + key) }
            for key in b.keys where a[key] == nil { missing.append(path + "." + key) }
            for (key, value) in a { if let other = b[key] { compare(value, other, path: path + "." + key, ignored: &ignored, missing: &missing) } }
        } else if let a = a as? [Any], let b = b as? [Any] {
            for (index, pair) in zip(a, b).enumerated() {
                compare(pair.0, pair.1, path: "\(path)[\(index)]", ignored: &ignored, missing: &missing)
            }
        }
    }
}
