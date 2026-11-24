import Foundation
import Testing
@testable import SenkuCore
@testable import SenkuUI

/// A paid loan or utility bill is a spend, and is logged as one; a card bill
/// is not, since what was bought on the card is.
@Suite struct DuesToExpensesTests {
    private func stores() -> (DueDateStore, MoneyStore) {
        let defaults = UserDefaults(suiteName: "DuesToExpensesTests.\(UUID().uuidString)")!
        let dues = DueDateStore(defaults: defaults)
        let expenses = MoneyStore(.expenses, defaults: defaults)
        dues.expenses = expenses
        return (dues, expenses)
    }

    private func due(_ category: String, amount: Double? = 1200) -> DueItem {
        DueItem(title: "Rent", category: category, amount: amount, firstDue: .now, repeats: .months)
    }

    @Test func aPaidUtilityIsLogged() throws {
        let (dues, expenses) = stores()
        let rent = due("Utilities")
        dues.save(rent)
        dues.markDone(rent.id)

        let entry = try #require(expenses.entries.first)
        #expect(entry.name == "Rent")
        #expect(entry.category == "Utilities")
        #expect(entry.amounts == [1200])
        #expect(entry.month == YearMonth(.now))
        #expect(dues.item(rent.id)?.history.last?.expenseID == entry.id)
    }

    @Test func aLoanGoesUnderLoanEMI() {
        let (dues, expenses) = stores()
        let loan = due("loan", amount: 100)
        dues.save(loan)
        dues.markDone(loan.id)
        #expect(expenses.entries.first?.category == "Loan / EMI")
    }

    @Test func aCardBillIsNot() {
        let (dues, expenses) = stores()
        let card = due("Credit Card")
        dues.save(card)
        dues.markDone(card.id)
        #expect(expenses.entries.isEmpty)
    }

    @Test func noAmountMeansNothingLogged() {
        let (dues, expenses) = stores()
        let bill = due("Utilities", amount: nil)
        dues.save(bill)
        dues.markDone(bill.id)
        #expect(expenses.entries.isEmpty)

        dues.markDone(bill.id, paid: 45.50)
        #expect(expenses.entries.first?.amounts == [45.50])
    }

    @Test func undoingTakesTheSpendBack() {
        let (dues, expenses) = stores()
        let rent = due("Utilities")
        dues.save(rent)
        dues.markDone(rent.id)
        dues.undoDone(rent.id)
        #expect(expenses.entries.isEmpty)
    }

    @Test func deletingTheHistoryLineTakesItBack() throws {
        let (dues, expenses) = stores()
        let rent = due("Utilities")
        dues.save(rent)
        dues.markDone(rent.id)
        let line = try #require(dues.item(rent.id)?.history.last)
        dues.removeCompletion(line.id, from: rent.id)
        #expect(expenses.entries.isEmpty)
    }

    /// The editor's "Undo last done" saves the whole item back.
    @Test func undoInTheEditorTakesItBack() throws {
        let (dues, expenses) = stores()
        let rent = due("Utilities")
        dues.save(rent)
        dues.markDone(rent.id)
        var edited = try #require(dues.item(rent.id))
        edited.undoDone()
        dues.save(edited)
        #expect(expenses.entries.isEmpty)
    }

    /// One of your own goes under its own name, which Expenses gains as a
    /// category — or matches, when Expenses already has it.
    @Test func aCustomCategoryIsLoggedUnderItsName() {
        let (dues, expenses) = stores()
        let gym = due("Gym", amount: 30)
        dues.save(gym)
        dues.markDone(gym.id)
        #expect(expenses.entries.first?.category == "Gym")
        #expect(expenses.categories.contains("Gym"))

        let rent = due("rent")
        dues.save(rent)
        dues.markDone(rent.id)
        #expect(expenses.entries.contains { $0.category == "Rent" })
        #expect(!expenses.customCategories.contains { $0.lowercased() == "rent" })
    }

    @Test func aCustomCategoryCanBeLeftOut() {
        let (dues, expenses) = stores()
        var gym = due("Gym", amount: 30)
        gym.logsExpense = false
        dues.save(gym)
        dues.markDone(gym.id)
        #expect(expenses.entries.isEmpty)
    }

    /// The switch is for your own categories: a loan is logged regardless.
    @Test func theSwitchDoesNotTouchTheDefaults() {
        let (dues, expenses) = stores()
        var loan = due("Loan", amount: 100)
        loan.logsExpense = false
        dues.save(loan)
        dues.markDone(loan.id)
        #expect(expenses.entries.count == 1)
    }

    @Test func noCategoryIsNotLogged() {
        let (dues, expenses) = stores()
        let bill = due("")
        dues.save(bill)
        dues.markDone(bill.id)
        #expect(expenses.entries.isEmpty)
    }

    @Test func withoutExpensesNothingIsLogged() {
        let (dues, expenses) = stores()
        dues.expenses = nil
        let rent = due("Utilities")
        dues.save(rent)
        dues.markDone(rent.id)
        #expect(expenses.entries.isEmpty)
        #expect(dues.item(rent.id)?.history.count == 1)
    }
}
