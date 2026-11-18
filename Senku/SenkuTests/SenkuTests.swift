import Foundation
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
        #expect(!catalogue.workoutGroups.isEmpty)
        // Cardio is a group with one region and no muscles — the shape the
        // coverage maths depends on.
        #expect(catalogue.workoutGroups.contains { !$0.isMuscle })
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

#if os(iOS)
import PDFKit

/// The reports are drawn with UIKit, so they are checked here, on iOS.
@MainActor
struct SeparateReportsTests {
    private func text(_ part: ReportPDF.Part) throws -> String {
        let defaults = UserDefaults(suiteName: "reports.\(UUID().uuidString)")!
        let weights = WeightLogStore(defaults: defaults)
        weights.add(try WeighIn(date: .now, weightKG: 80))
        let expenses = MoneyStore(.expenses, defaults: defaults)
        expenses.save(MoneyEntry(month: .current(), name: "Costco", category: "Groceries", amounts: [40, 12]))
        let income = MoneyStore(.income, defaults: defaults)
        income.save(MoneyEntry(month: .current(), name: "GTA", amounts: [1050]))
        let anime = AnimeStore(defaults: defaults)

        let url = try #require(ReportPDF.build(
            profile: nil,
            weights: weights,
            records: RecordStore(defaults: defaults),
            library: ExerciseLibrary(defaults: defaults),
            plans: TrainingPlanStore(defaults: defaults),
            workouts: WorkoutStore(defaults: defaults),
            anime: anime,
            water: WaterStore(defaults: defaults),
            intake: IntakeStore(defaults: defaults),
            dues: DueDateStore(defaults: defaults),
            expenses: expenses,
            income: income,
            unitSystem: .metric,
            part: part
        ))
        #expect(url.lastPathComponent.hasPrefix("Senku \(part == .health ? "Health" : part == .money ? "Money" : "Watchlist") report"))
        // Headings are drawn in capitals.
        return try #require(PDFDocument(url: url)?.string).lowercased()
    }

    @Test func healthLeavesMoneyOut() throws {
        let health = try text(.health)
        #expect(health.contains("weight"))
        #expect(!health.contains("costco") && !health.contains("income"))
    }

    @Test func moneyLeavesHealthOut() throws {
        let money = try text(.money)
        #expect(money.contains("expenses") && money.contains("income") && money.contains("groceries"))
        #expect(!money.contains("weight"))
    }
}
#endif
