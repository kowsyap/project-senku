import Foundation
import Testing
@testable import SenkuCore
@testable import SenkuUI

@Suite struct MoneyExportTests {
    private let entries = [
        MoneyEntry(month: YearMonth(year: 2026, month: 9), name: "Rent", category: "Rent", amounts: [1200]),
        MoneyEntry(month: YearMonth(year: 2026, month: 10), name: "Groceries", category: "Groceries", amounts: [62.10]),
        MoneyEntry(month: YearMonth(year: 2026, month: 11), name: "Rent", category: "Rent", amounts: [1200], note: "Nov, paid"),
    ]

    @Test func everythingIsInByDefault() {
        let filter = MoneyExport(from: YearMonth(year: 2026, month: 9), to: YearMonth(year: 2026, month: 11))
        #expect(filter.entries(entries, kind: .expenses).count == 3)
    }

    @Test func monthsAndCategoriesNarrowIt() {
        var filter = MoneyExport(from: YearMonth(year: 2026, month: 10), to: YearMonth(year: 2026, month: 11))
        #expect(filter.entries(entries, kind: .expenses).count == 2)
        filter.excluded = ["Groceries"]
        #expect(filter.entries(entries, kind: .expenses).map(\.name) == ["Rent"])
    }

    /// From and To the wrong way round still mean the months between.
    @Test func aBackwardsRangeStillWorks() {
        let filter = MoneyExport(from: YearMonth(year: 2026, month: 11), to: YearMonth(year: 2026, month: 10))
        #expect(filter.entries(entries, kind: .expenses).count == 2)
    }

    /// Income is filtered by where it came from.
    @Test func incomeGoesBySource() {
        let income = [
            MoneyEntry(month: YearMonth(year: 2026, month: 10), name: "Salary", amounts: [2100]),
            MoneyEntry(month: YearMonth(year: 2026, month: 10), name: "Refund", amounts: [12]),
        ]
        #expect(MoneyExport.groups(income, kind: .income) == ["Refund", "Salary"])
        var filter = MoneyExport(from: YearMonth(year: 2026, month: 10), to: YearMonth(year: 2026, month: 10))
        filter.excluded = ["Refund"]
        #expect(filter.entries(income, kind: .income).map(\.name) == ["Salary"])
    }

    @Test func theFileIsNamedForWhatIsInIt() {
        var filter = MoneyExport(from: YearMonth(year: 2026, month: 11), to: YearMonth(year: 2026, month: 11))
        #expect(filter.fileName(entries, kind: .expenses) == "Senku Expenses Nov 2026.csv")

        filter.from = YearMonth(year: 2026, month: 6)
        #expect(filter.fileName(entries, kind: .expenses) == "Senku Expenses Jun–Nov 2026.csv")

        filter.from = YearMonth(year: 2025, month: 12)
        filter.excluded = ["Groceries"]
        #expect(filter.fileName(entries, kind: .expenses) == "Senku Expenses Rent Dec 2025–Nov 2026.csv")
    }

    @Test func theCSVQuotesWhatNeedsIt() {
        let filter = MoneyExport(from: YearMonth(year: 2026, month: 11), to: YearMonth(year: 2026, month: 11))
        let lines = filter.csv(entries, kind: .expenses).split(separator: "\n")
        #expect(lines.first == "Month,Name,Category,Amounts,Total,Note")
        #expect(lines.last == #"2026-11,Rent,Rent,1200.00,1200.00,"Nov, paid""#)
    }
}
