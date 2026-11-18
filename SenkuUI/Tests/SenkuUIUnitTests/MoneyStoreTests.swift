import Foundation
import Testing
@testable import SenkuUI
import SenkuCore

@MainActor
@Suite struct MoneyStoreTests {
    private func fresh() -> UserDefaults { UserDefaults(suiteName: UUID().uuidString)! }
    private let nov = YearMonth(year: 2026, month: 11)

    @Test func savedEntriesComeBackNewestMonthFirst() {
        let defaults = fresh()
        let store = MoneyStore(.expenses, defaults: defaults)
        store.save(MoneyEntry(month: nov.adding(-1), name: "Costco", category: "Groceries", amounts: [40]))
        store.save(MoneyEntry(month: nov, name: "Uber", category: "Transport", amounts: [5, 7]))

        let reopened = MoneyStore(.expenses, defaults: defaults)
        #expect(reopened.entries.map(\.name) == ["Uber", "Costco"])
        #expect(reopened.entries(in: nov).first?.total == 12)
        #expect(reopened.earliest == nov.adding(-1))
    }

    @Test func expensesAndIncomeAreKeptApart() {
        let defaults = fresh()
        MoneyStore(.income, defaults: defaults).save(MoneyEntry(month: nov, name: "GTA", amounts: [1050, 1050]))
        #expect(MoneyStore(.expenses, defaults: defaults).entries.isEmpty)
        #expect(MoneyStore(.income, defaults: defaults).entries.first?.total == 2100)
    }

    @Test func customCategoriesAddOnceAndLeaveToMiscellaneous() {
        let defaults = fresh()
        let store = MoneyStore(.expenses, defaults: defaults)
        #expect(store.addCategory(" Pets ") == "Pets")
        #expect(store.addCategory("pets") == "Pets")
        #expect(store.addCategory("groceries") == "Groceries")
        #expect(store.categories.last == "Pets")
        #expect(store.categories.count == ExpenseCategory.defaults.count + 1)

        store.save(MoneyEntry(month: nov, name: "Vet", category: "Pets", amounts: [80]))
        store.removeCategory("Pets")
        #expect(store.entries.first?.category == ExpenseCategory.fallback)
        #expect(MoneyStore(.expenses, defaults: defaults).customCategories.isEmpty)
    }

    @Test func aBackupBringsBothBackOnce() {
        let old = fresh(), new = fresh()
        let spends = MoneyStore(.expenses, defaults: old)
        let pay = MoneyStore(.income, defaults: old)
        spends.addCategory("GMU")
        spends.save(MoneyEntry(month: nov, name: "Books", category: "GMU", amounts: [30]))
        pay.save(MoneyEntry(month: nov, name: "GTA", amounts: [1050]))

        var document = SenkuImportDocument()
        document.expenses = spends.entries
        document.expenseCategories = spends.customCategories
        document.income = pay.entries

        let restoredSpends = MoneyStore(.expenses, defaults: new)
        let restoredPay = MoneyStore(.income, defaults: new)
        restoredSpends.restoreCategories(document.expenseCategories ?? [])
        for entry in document.expenses ?? [] { restoredSpends.restore(entry) }
        for entry in document.income ?? [] { restoredPay.restore(entry) }
        #expect(restoredSpends.entries == spends.entries)
        #expect(restoredSpends.customCategories == ["GMU"])
        #expect(restoredPay.entries == pay.entries)
        #expect(!restoredPay.restore(pay.entries[0]))
    }
}
