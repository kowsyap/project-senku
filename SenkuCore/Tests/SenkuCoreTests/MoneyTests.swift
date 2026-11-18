import Foundation
import Testing
@testable import SenkuCore

@Suite struct YearMonthTests {
    @Test func addingCrossesYears() {
        #expect(YearMonth(year: 2026, month: 11).adding(3) == YearMonth(year: 2027, month: 2))
        #expect(YearMonth(year: 2026, month: 1).adding(-1) == YearMonth(year: 2025, month: 12))
        #expect(YearMonth(year: 2026, month: 1).adding(-13) == YearMonth(year: 2024, month: 12))
    }

    @Test func spanIsInclusive() {
        let span = YearMonth.span(YearMonth(year: 2025, month: 11), YearMonth(year: 2026, month: 2))
        #expect(span.map(\.month) == [11, 12, 1, 2])
        #expect(YearMonth.span(YearMonth(year: 2026, month: 2), YearMonth(year: 2026, month: 1)).isEmpty)
    }

    @Test func periods() {
        let now = YearMonth(year: 2026, month: 11)
        #expect(MoneyPeriod.thisMonth.range(now: now, earliest: nil) == now...now)
        #expect(MoneyPeriod.months(3).range(now: now, earliest: nil).lowerBound == YearMonth(year: 2026, month: 9))
        #expect(MoneyPeriod.thisYear.range(now: now, earliest: nil).lowerBound == YearMonth(year: 2026, month: 1))
        #expect(MoneyPeriod.all.range(now: now, earliest: YearMonth(year: 2024, month: 8)).lowerBound == YearMonth(year: 2024, month: 8))
        let custom = MoneyPeriod.custom(YearMonth(year: 2026, month: 5), YearMonth(year: 2026, month: 2))
        #expect(custom.range(now: now, earliest: nil) == YearMonth(year: 2026, month: 2)...YearMonth(year: 2026, month: 5))
        #expect(MoneyPeriod.previous(to: YearMonth(year: 2026, month: 9)...now)
            == YearMonth(year: 2026, month: 6)...YearMonth(year: 2026, month: 8))
    }
}

@Suite struct MoneyReportTests {
    private let sep = YearMonth(year: 2026, month: 9)
    private let oct = YearMonth(year: 2026, month: 10)
    private let nov = YearMonth(year: 2026, month: 11)

    private var entries: [MoneyEntry] {
        [
            MoneyEntry(month: sep, name: "Uber", category: "Transport", amounts: [10, 5]),
            MoneyEntry(month: sep, name: "Costco", category: "Groceries", amounts: [60]),
            MoneyEntry(month: nov, name: "Uber", category: "Transport", amounts: [25]),
            MoneyEntry(month: nov, name: "Rent", category: "Rent", amounts: [450]),
            MoneyEntry(month: YearMonth(year: 2026, month: 6), name: "Old", category: "Gifts", amounts: [99]),
        ]
    }

    @Test func totalsAndEmptyMonthsCount() {
        let report = MoneyReport(entries, range: sep...nov, grouping: .category)
        #expect(report.total == 550)
        #expect(report.count == 4)
        #expect(report.monthly.map(\.total) == [75, 0, 475])
        #expect(abs(report.monthlyAverage - 550.0 / 3) < 0.001)
        #expect(report.highestMonth?.month == nov)
    }

    @Test func groupsAreLargestFirstWithShares() {
        let report = MoneyReport(entries, range: sep...nov, grouping: .category)
        #expect(report.groups.map(\.key) == ["Rent", "Groceries", "Transport"])
        #expect(abs(report.groups[0].share - 450.0 / 550) < 0.001)
        #expect(report.names.first { $0.key == "Uber" }?.count == 2)
        #expect(report.names.first { $0.key == "Uber" }?.total == 40)
    }

    @Test func theRestFoldIntoOther() {
        let report = MoneyReport(entries, range: sep...nov, grouping: .category)
        let top = report.topGroups(1)
        #expect(top.map(\.key) == ["Rent", MoneyReport.other])
        #expect(top[1].total == 100)
        let stacked = report.stacked(1)
        #expect(stacked.contains(MoneyReport.Point(month: sep, key: MoneyReport.other, total: 75)))
        #expect(stacked.contains(MoneyReport.Point(month: nov, key: "Rent", total: 450)))
    }

    @Test func oneGroupOnly() {
        let report = MoneyReport(entries, range: sep...nov, grouping: .category, only: "Transport")
        #expect(report.total == 40)
        #expect(report.groups.map(\.key) == ["Transport"])
    }

    @Test func incomeGroupsBySource() {
        let pay = [
            MoneyEntry(month: nov, name: "GTA", amounts: [1050, 1050]),
            MoneyEntry(month: nov, name: "IRS", amounts: [556]),
        ]
        let report = MoneyReport(pay, range: nov...nov, grouping: .name)
        #expect(report.groups.map(\.key) == ["GTA", "IRS"])
        #expect(report.total == 2656)
    }

    @Test func changeFromThePreviousPeriod() {
        let now = MoneyReport(entries, range: nov...nov, grouping: .category)
        let before = MoneyReport(entries, range: oct...oct, grouping: .category)
        #expect(now.change(from: before) == nil)
        let sept = MoneyReport(entries, range: sep...sep, grouping: .category)
        #expect(abs((now.change(from: sept) ?? 0) - (475.0 - 75) / 75) < 0.001)
    }
}

@Suite struct MoneySuggestionTests {
    private let entries = [
        MoneyEntry(month: YearMonth(year: 2026, month: 1), name: "Uber", category: "Transport", amounts: [5]),
        MoneyEntry(month: YearMonth(year: 2026, month: 2), name: "Uber", category: "Transport", amounts: [5]),
        MoneyEntry(month: YearMonth(year: 2026, month: 3), name: "Uber Eats", category: "Restaurants", amounts: [9]),
        MoneyEntry(month: YearMonth(year: 2026, month: 4), name: "Super Canton", category: "Restaurants", amounts: [20]),
        MoneyEntry(month: YearMonth(year: 2026, month: 5), name: "uber one", category: "Subscriptions", amounts: [10]),
        MoneyEntry(month: YearMonth(year: 2026, month: 6), name: "Uber One", category: "Subscriptions", amounts: [10]),
    ]

    @Test func startsWithFirstThenMostUsed() {
        let names = MoneySuggestions.matching("ub", in: entries).map(\.name)
        // Uber and Uber One are used twice each; the more recent comes first.
        #expect(names == ["Uber One", "Uber", "Uber Eats"])
        #expect(MoneySuggestions.matching("canton", in: entries).map(\.name) == ["Super Canton"])
    }

    @Test func fillsTheLastCategoryAndSpelling() {
        let one = MoneySuggestions.matching("one", in: entries)
        #expect(one == [MoneySuggestions.Suggestion(name: "Uber One", category: "Subscriptions")])
    }

    @Test func theNameAlreadyTypedIsNotOffered() {
        #expect(!MoneySuggestions.matching("uber", in: entries).map(\.name).contains("Uber"))
        #expect(MoneySuggestions.matching("  ", in: entries).isEmpty)
    }
}

@Suite struct CatalogueVersionTests {
    /// The plan skill's script hashes the same ids the same way; the two must
    /// agree, or every imported plan would claim an older exercise list.
    @Test func matchesTheSkillsScript() throws {
        let catalogue = ExerciseCatalogue.bundled
        let skill = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("skills/senku-plan/reference/catalogue.md")
        let markdown = try String(contentsOf: skill, encoding: .utf8)
        #expect(catalogue.version.count == 8)
        #expect(markdown.contains("Catalogue version: `\(catalogue.version)`"))
    }
}
