import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// What Siri actually says. The intents themselves can only be checked by
/// talking to a phone; the words can be checked here.
@Suite struct SpokenSummaryTests {
    /// Real targets from a real plan, rather than numbers invented here: the
    /// wording has to survive whatever the calculator actually produces.
    private let targets: MacroTargets = {
        let profile = ProfileStore.Profile(
            metrics: try! BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 84),
            activityLevel: .moderate,
            goal: .moderateCut,
            formula: .automatic,
            unitSystem: .metric
        )
        return profile.plan.macros
    }()

    private func weighIns(_ values: [(daysAgo: Int, kg: Double)]) -> WeightSeries {
        WeightSeries(values.compactMap {
            try? WeighIn(
                date: Calendar.current.date(byAdding: .day, value: -$0.daysAgo, to: .now)!,
                weightKG: $0.kg,
                source: .manual
            )
        })
    }

    // MARK: - Weight

    @Test func anEmptyLogSaysSoRatherThanReadingOutAZero() {
        #expect(SpokenSummary.weight(WeightSeries([]), in: .metric) == "Nothing weighed in yet.")
    }

    @Test func aFallingTrendIsReportedAsDown() {
        let spoken = SpokenSummary.weight(
            weighIns([(14, 82), (7, 81), (0, 80)]), in: .metric
        )

        #expect(spoken.hasPrefix("80.0 kg"))
        #expect(spoken.contains("down"))
        #expect(spoken.contains("a week on the trend"))
    }

    @Test func poundsAreSpokenWhenThatIsWhatTheProfileUses() {
        let spoken = SpokenSummary.weight(weighIns([(0, 80)]), in: .imperial)
        #expect(spoken.contains("lb"))
        #expect(!spoken.contains("kg"))
    }

    // MARK: - Water

    @Test func noWaterYetGivesTheGoalRatherThanAPercentage() {
        let day = WaterDay(date: .now, entries: [], goal: WaterGoal(baseML: 2950))
        let spoken = SpokenSummary.water(day)

        #expect(spoken.contains("No water logged yet"))
        #expect(spoken.contains("2,950"))
        #expect(!spoken.contains("0 percent"))
    }

    @Test func aPartDayReportsWhatIsLeft() throws {
        let day = WaterDay(
            date: .now,
            entries: [try WaterEntry(date: .now, millilitres: 1450)],
            goal: WaterGoal(baseML: 2450)
        )
        let spoken = SpokenSummary.water(day)

        #expect(spoken.contains("1,450 of 2,450 millilitres"))
        #expect(spoken.contains("59 percent"))
        #expect(spoken.contains("1,000 to go"))
    }

    @Test func meetingTheGoalIsSaidPlainly() throws {
        let day = WaterDay(
            date: .now,
            entries: [try WaterEntry(date: .now, millilitres: 2500)],
            goal: WaterGoal(baseML: 2450)
        )

        #expect(SpokenSummary.water(day).contains("goal met"))
    }

    // MARK: - Food

    /// The app's own rule, and it matters more aloud: "nothing logged" and
    /// "zero grams of protein" are different claims, and only one is true
    /// before breakfast.
    @Test func anUnloggedDayIsNotZero() {
        let day = IntakeDay(date: .now, entries: [], targets: targets)
        let spoken = SpokenSummary.intake(day)

        #expect(spoken.hasPrefix("Nothing logged today"))
        #expect(!spoken.contains("0 grams"))
        #expect(spoken.contains("\(Int(targets.proteinGrams.rounded())) grams"))
    }

    @Test func unitsAreSpelledOutRatherThanAbbreviated() throws {
        let day = IntakeDay(
            date: .now,
            entries: [try IntakeEntry(date: .now, proteinG: 96, carbsG: 200, fatG: 60)],
            targets: targets
        )
        let spoken = SpokenSummary.intake(day)

        #expect(spoken.contains("96 grams of"))
        #expect(!spoken.contains(" g "), "\"g\" is read aloud as \"gee\"")
        #expect(!spoken.contains("/"), "a slash is read aloud as \"slash\"")
    }

    @Test func proteinAloneSaysWhatIsLeft() throws {
        let day = IntakeDay(
            date: .now,
            entries: [try IntakeEntry(date: .now, proteinG: 100, carbsG: 0, fatG: 0)],
            targets: targets
        )

        let remaining = Int((targets.proteinGrams - 100).rounded())
        #expect(SpokenSummary.protein(day).contains("\(remaining) grams to go"))
    }

    @Test func aMetProteinTargetSaysSoInsteadOfCountingDown() throws {
        let day = IntakeDay(
            date: .now,
            entries: [try IntakeEntry(date: .now, proteinG: targets.proteinGrams + 5, carbsG: 0, fatG: 0)],
            targets: targets
        )

        #expect(SpokenSummary.protein(day).contains("Target met"))
    }

    @Test func oneGramIsSingular() throws {
        let day = IntakeDay(
            date: .now,
            entries: [try IntakeEntry(date: .now, proteinG: 1, carbsG: 0, fatG: 0)],
            targets: targets
        )

        #expect(SpokenSummary.protein(day).hasPrefix("1 gram of"))
    }
}
