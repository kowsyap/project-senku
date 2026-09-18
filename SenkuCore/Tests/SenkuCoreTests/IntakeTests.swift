import Foundation
import Testing
@testable import SenkuCore

/// The rules F5 is accountable to: derived calories are never silently merged
/// with entered ones, a day with nothing in it is not a day you ate nothing,
/// and calories are judged as a band rather than a ceiling.
@Suite struct IntakeTests {
    private func targets(
        calories: Double = 2500,
        protein: Double = 180,
        carbs: Double = 250,
        fat: Double = 70
    ) -> MacroTargets {
        MacroTargets(
            calories: calories,
            proteinGrams: protein,
            fatGrams: fat,
            carbGrams: carbs,
            fiberGrams: 30,
            waterML: 2500,
            trainingDayExtraWaterML: 500
        )
    }

    @Test func caloriesComeFromTheMacrosByAtwater() throws {
        let entry = try IntakeEntry(proteinG: 40, carbsG: 30, fatG: 10)

        #expect(entry.derivedCalories == 40 * 4 + 30 * 4 + 10 * 9)
        #expect(entry.calories == entry.derivedCalories)
    }

    /// A figure off a packet wins for the total — the label knows about the oil
    /// the arithmetic cannot see — but the derived figure is still there to be
    /// shown beside it.
    @Test func anEnteredCalorieFigureIsKeptAndNotAveraged() throws {
        let entry = try IntakeEntry(proteinG: 40, carbsG: 30, fatG: 10, enteredCalories: 400)

        #expect(entry.calories == 400)
        #expect(entry.derivedCalories == 370)
        #expect(entry.hasCalorieDisagreement == false)   // 30 kcal, within rounding
    }

    @Test func aRealDisagreementIsFlagged() throws {
        let entry = try IntakeEntry(proteinG: 40, carbsG: 30, fatG: 10, enteredCalories: 600)

        #expect(entry.hasCalorieDisagreement)
    }

    @Test func gramsOutsideAPlausibleMealAreRefused() {
        #expect(throws: ValidationError.self) { try IntakeEntry(proteinG: 1200) }
        #expect(throws: ValidationError.self) { try IntakeEntry(carbsG: -5) }
    }

    @Test func aBlankNameIsNoName() throws {
        #expect(try IntakeEntry(name: "   ", proteinG: 20).name == nil)
        #expect(try IntakeEntry(name: "Eggs", proteinG: 20).name == "Eggs")
    }

    // MARK: - The day

    @Test func aDayAddsUpItsEntries() throws {
        let day = IntakeDay(
            date: .now,
            entries: [
                try IntakeEntry(proteinG: 40, carbsG: 50, fatG: 10, fiberG: 4),
                try IntakeEntry(proteinG: 30, carbsG: 20, fatG: 20),
            ],
            targets: targets()
        )

        #expect(day.proteinG == 70)
        #expect(day.carbsG == 70)
        #expect(day.fatG == 30)
        #expect(day.fiberG == 4)
        #expect(day.calories == 70 * 4 + 70 * 4 + 30 * 9)
    }

    @Test func nothingLoggedIsNotZeroEaten() {
        let day = IntakeDay(date: .now, entries: [], targets: targets())

        #expect(day.isUnlogged)
        #expect(day.isCaloriesMet == false)
        #expect(day.spoken == "Nothing logged")
    }

    /// Protein is a floor: over the target still counts.
    @Test func proteinIsMetAtOrAboveTheTarget() throws {
        let over = IntakeDay(
            date: .now,
            entries: [try IntakeEntry(proteinG: 200)],
            targets: targets(protein: 180)
        )
        let under = IntakeDay(
            date: .now,
            entries: [try IntakeEntry(proteinG: 179)],
            targets: targets(protein: 180)
        )

        #expect(over.isProteinMet)
        #expect(under.isProteinMet == false)
    }

    /// Calories are a band. This is the one that stops a 1,200 kcal day on a
    /// 2,500 target reading as a success because it was "under".
    @Test func caloriesAreMetOnlyNearTheTarget() throws {
        func day(_ calories: Double) throws -> IntakeDay {
            IntakeDay(
                date: .now,
                entries: [try IntakeEntry(carbsG: calories / 4)],
                targets: targets(calories: 2500)
            )
        }

        #expect(try day(2500).isCaloriesMet)
        #expect(try day(2300).isCaloriesMet)          // 8% under
        #expect(try day(2700).isCaloriesMet)          // 8% over
        #expect(try day(1200).isCaloriesMet == false) // starving is not success
        #expect(try day(3200).isCaloriesMet == false)
    }

    // MARK: - The log

    @Test func theLogGroupsByDay() throws {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!

        let log = IntakeLog([
            try IntakeEntry(date: .now, proteinG: 40),
            try IntakeEntry(date: .now, proteinG: 20),
            try IntakeEntry(date: yesterday, proteinG: 10),
        ])

        #expect(log.entries(on: .now).count == 2)
        #expect(log.day(.now, targets: targets()).proteinG == 60)
        #expect(log.day(yesterday, targets: targets()).proteinG == 10)
    }

    /// The figure `AdaptiveMaintenance` needs. Days you did not log are left
    /// out, not counted as zero — otherwise a fortnight with four blank days
    /// reports an intake you never ate and moves your maintenance estimate
    /// hundreds of calories on the strength of it.
    @Test func averageCaloriesIgnoresUnloggedDays() throws {
        let calendar = Calendar.current
        func day(_ ago: Int) -> Date { calendar.date(byAdding: .day, value: -ago, to: .now)! }

        let log = IntakeLog([
            try IntakeEntry(date: day(0), carbsG: 500),   // 2000 kcal
            try IntakeEntry(date: day(1), carbsG: 750),   // 3000 kcal
            // day 2 and 3: nothing logged
        ])

        let average = try #require(log.averageCalories(days: 4))

        #expect(average.calories == 2500)
        #expect(average.loggedDays == 2)
    }

    @Test func averageCaloriesIsNilWhenNothingWasLogged() {
        #expect(IntakeLog([]).averageCalories(days: 14) == nil)
    }

    @Test func aFavouriteBecomesAFreshEntryEachTime() throws {
        let favourite = FoodFavourite(name: "Shake", proteinG: 30, carbsG: 5, fatG: 2)

        let first = try #require(favourite.entry())
        let second = try #require(favourite.entry())

        #expect(first.id != second.id)
        #expect(first.name == "Shake")
        #expect(first.proteinG == 30)
        #expect(favourite.calories == 30 * 4 + 5 * 4 + 2 * 9)
    }
}
