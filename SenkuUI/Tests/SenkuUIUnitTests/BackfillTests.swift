import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// What the streak screen adds for a past day lands on that day — not today,
/// which is the day it was typed.
@MainActor
@Suite struct BackfillTests {
    private let calendar = Calendar.current
    private var yesterdayNoon: Date {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: yesterday)!
    }
    private func suite() -> UserDefaults {
        UserDefaults(suiteName: "senku.backfill.\(UUID().uuidString)")!
    }

    @Test func forgottenWaterCountsForItsDay() {
        let water = WaterStore(defaults: suite())
        water.add(millilitres: 750, at: yesterdayNoon)
        #expect(water.log.totalML(on: yesterdayNoon) == 750)
        #expect(water.log.totalML(on: .now) == 0)
    }

    @Test func forgottenProteinAndCaloriesCountForTheirDay() {
        let intake = IntakeStore(defaults: suite())
        _ = intake.addProtein(40, at: yesterdayNoon)
        _ = intake.addCalories(500, at: yesterdayNoon)
        let yesterday = intake.entries.filter { calendar.isDate($0.date, inSameDayAs: yesterdayNoon) }
        #expect(yesterday.reduce(0) { $0 + $1.proteinG } == 40)
        #expect(yesterday.reduce(0) { $0 + $1.calories } == 40 * 4 + 500)
        #expect(!intake.entries.contains { calendar.isDateInToday($0.date) })
    }

    @Test func creatineCanBeMarkedForAPastDay() {
        let water = WaterStore(defaults: suite())
        water.setCreatine(true, on: yesterdayNoon)
        #expect(water.tookCreatine(on: yesterdayNoon))
        #expect(!water.tookCreatine(on: .now))
    }

    // MARK: - Setting a past day's total

    private func at(_ hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: yesterdayNoon)!
    }

    @Test func raisingWaterAddsTheDifference() {
        let water = WaterStore(defaults: suite())
        water.add(millilitres: 500, at: at(9))
        water.setTotal(1500, on: yesterdayNoon)
        #expect(water.total(on: yesterdayNoon) == 1500)
        #expect(water.entries.count == 2)
    }

    /// Down comes off the latest drinks; the morning's stay as logged.
    @Test func loweringWaterTrimsTheLatestDrinksFirst() throws {
        let water = WaterStore(defaults: suite())
        water.add(millilitres: 250, at: at(8))
        water.add(millilitres: 500, at: at(13))
        water.add(millilitres: 750, at: at(18))

        water.setTotal(600, on: yesterdayNoon)

        #expect(water.total(on: yesterdayNoon) == 600)
        let left = water.entries.sorted { $0.date < $1.date }
        #expect(left.map(\.millilitres) == [250, 350])
        #expect(left.first?.date == at(8))
    }

    @Test func waterCanBeSetToNothing() {
        let water = WaterStore(defaults: suite())
        water.add(millilitres: 500, at: at(9))
        water.setTotal(0, on: yesterdayNoon)
        #expect(water.total(on: yesterdayNoon) == 0)
        #expect(water.entries.isEmpty)
    }

    /// A meal carries other numbers; lowering protein shrinks only the quick
    /// entries, and stops at what the meals account for.
    @Test func loweringProteinNeverTouchesAMeal() throws {
        let intake = IntakeStore(defaults: suite())
        let meal = try IntakeEntry(date: at(13), proteinG: 40, carbsG: 60, fatG: 15)
        _ = intake.add(meal)
        _ = intake.addProtein(50, at: at(20))
        #expect(intake.total(.protein, on: yesterdayNoon) == 90)
        #expect(intake.floor(.protein, on: yesterdayNoon) == 40)

        intake.setTotal(.protein, 60, on: yesterdayNoon)
        #expect(intake.total(.protein, on: yesterdayNoon) == 60)
        #expect(intake.entries.first { $0.id == meal.id } == meal)

        // Below the meal: held at the meal.
        intake.setTotal(.protein, 10, on: yesterdayNoon)
        #expect(intake.total(.protein, on: yesterdayNoon) == 40)
        #expect(intake.entries.first { $0.id == meal.id } == meal)
    }

    @Test func raisingAndLoweringCalories() throws {
        let intake = IntakeStore(defaults: suite())
        _ = intake.add(try IntakeEntry(date: at(13), proteinG: 30, carbsG: 50, fatG: 10))  // 410 kcal
        intake.setTotal(.calories, 1000, on: yesterdayNoon)
        #expect(abs(intake.total(.calories, on: yesterdayNoon) - 1000) < 0.01)

        intake.setTotal(.calories, 700, on: yesterdayNoon)
        #expect(abs(intake.total(.calories, on: yesterdayNoon) - 700) < 0.01)
        #expect(intake.floor(.calories, on: yesterdayNoon) == 410)
    }
}
