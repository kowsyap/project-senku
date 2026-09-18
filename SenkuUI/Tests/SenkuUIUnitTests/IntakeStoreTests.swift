import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

@MainActor
@Suite struct IntakeStoreTests {
    private func store(_ name: String = UUID().uuidString) -> IntakeStore {
        IntakeStore(defaults: UserDefaults(suiteName: name)!)
    }

    private func profile() throws -> ProfileStore.Profile {
        ProfileStore.Profile(
            metrics: try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 80),
            activityLevel: .moderate,
            goal: .maintain,
            formula: .automatic,
            unitSystem: .metric
        )
    }

    @Test func aBareProteinFigureIsAnEntry() throws {
        let store = store()

        #expect(store.addProtein(40))
        #expect(store.entries.count == 1)
        #expect(store.entries[0].proteinG == 40)
        #expect(store.entries[0].name == nil)
    }

    /// The other bare case: calories with no macros known.
    @Test func aBareCalorieFigureIsAnEntry() throws {
        let store = store()

        #expect(store.addCalories(700))
        #expect(store.entries.count == 1)
        #expect(store.entries[0].calories == 700)
        #expect(store.entries[0].proteinG == 0)
    }

    @Test func zeroCaloriesIsNotAnEntry() {
        let store = store()

        #expect(store.addCalories(0) == false)
        #expect(store.entries.isEmpty)
    }

    @Test func anEmptyEntryIsRefused() throws {
        let store = store()

        #expect(store.add(try IntakeEntry(name: "Water, basically")) == false)
        #expect(store.entries.isEmpty)
    }

    /// The screen is a comparison. Without a profile there is nothing to
    /// compare against, and inventing a target would be worse than saying so.
    @Test func thereIsNoDayWithoutAProfile() {
        #expect(store().day(profile: nil) == nil)
    }

    @Test func theDayIsMeasuredAgainstTheProfilesPlan() throws {
        let store = store()
        let profile = try profile()

        store.addProtein(50)
        let day = try #require(store.day(profile: profile))

        #expect(day.proteinG == 50)
        #expect(day.targets.proteinGrams == profile.plan.macros.proteinGrams)
    }

    // MARK: - Favourites

    @Test func loggingAFavouriteCountsTheUse() throws {
        let store = store()
        let shake = FoodFavourite(name: "Shake", proteinG: 30, carbsG: 5, fatG: 2)
        store.save(shake)

        #expect(store.log(shake))
        #expect(store.log(shake))

        #expect(store.entries.count == 2)
        #expect(store.favourites.first?.timesUsed == 2)
        #expect(store.entries.allSatisfy { $0.name == "Shake" })
    }

    /// Two shakes is one thing you did, logged once with the count in the name.
    @Test func servingsMultiplyTheMacrosIntoOneEntry() throws {
        let store = store()
        let shake = FoodFavourite(name: "Shake", proteinG: 30, carbsG: 5, fatG: 2)
        store.save(shake)

        #expect(store.log(shake, servings: 2))

        #expect(store.entries.count == 1)
        #expect(store.entries[0].proteinG == 60)
        #expect(store.entries[0].name == "Shake ×2")
        // A double serving is one reach for the menu, not two.
        #expect(store.favourites.first?.timesUsed == 1)
    }

    @Test func aCaloriesOnlyFavouriteScalesToo() throws {
        let store = store()
        let takeaway = FoodFavourite(name: "Takeaway", enteredCalories: 900)
        store.save(takeaway)

        #expect(store.log(takeaway, servings: 2))
        #expect(store.entries[0].calories == 1800)
        #expect(store.entries[0].proteinG == 0)
    }

    /// Most-used first, so the four things you actually eat rise to the top
    /// without a sorting screen.
    @Test func favouritesAreOrderedByUse() {
        let store = store()
        let rice = FoodFavourite(name: "Rice", carbsG: 60, timesUsed: 1)
        let eggs = FoodFavourite(name: "Eggs", proteinG: 12, timesUsed: 9)
        store.save(rice)
        store.save(eggs)

        #expect(store.orderedFavourites.map(\.name) == ["Eggs", "Rice"])
    }

    // MARK: - Streaks

    @Test func proteinDaysAreTheDaysTheTargetWasReached() throws {
        let store = store()
        let profile = try profile()
        let target = profile.plan.macros.proteinGrams
        let calendar = Calendar.current

        store.add(try IntakeEntry(date: .now, proteinG: target))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!
        store.add(try IntakeEntry(date: yesterday, proteinG: target / 2))

        let days = store.proteinDays(profile: profile)

        #expect(days.contains(calendar.startOfDay(for: .now)))
        #expect(!days.contains(calendar.startOfDay(for: yesterday)))
    }

    /// The band, from the store's side: eating far under target is not a day
    /// the calorie streak should count.
    @Test func calorieDaysNeedTheBandAndNotJustBeingUnder() throws {
        let store = store()
        let profile = try profile()
        let target = profile.plan.macros.calories
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!

        store.add(try IntakeEntry(date: .now, carbsG: target / 4))
        store.add(try IntakeEntry(date: yesterday, carbsG: target / 4 * 0.4))

        let days = store.calorieDays(profile: profile)

        #expect(days.contains(calendar.startOfDay(for: .now)))
        #expect(!days.contains(calendar.startOfDay(for: yesterday)))
    }

    @Test func aDayWithNothingLoggedIsInNoStreak() throws {
        let store = store()

        #expect(store.proteinDays(profile: try profile()).isEmpty)
        #expect(store.calorieDays(profile: try profile()).isEmpty)
    }

    // MARK: - Two processes

    /// A widget, a shortcut or a second store writing to the same container
    /// must not have its entry erased by the next write from here.
    @Test func aWriteFromAnotherStoreSurvivesTheNextLog() throws {
        let suite = UUID().uuidString
        let app = store(suite)
        let elsewhere = store(suite)

        elsewhere.addProtein(30)
        app.addProtein(20)

        #expect(app.entries.count == 2)
    }

    @Test func restoringTheSameEntryTwiceIsANoOp() throws {
        let store = store()
        let entry = try IntakeEntry(proteinG: 25)

        store.restore(entry)
        store.restore(entry)

        #expect(store.entries.count == 1)
    }
}
