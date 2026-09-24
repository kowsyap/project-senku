import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// The part of the photo feature that does not need a camera, a model, or an
/// iOS 27 device: what happens to the numbers once they come back.
@Suite struct FoodEstimateTests {
    private func estimate(
        name: String = "chicken and rice",
        protein: Double = 40,
        carbs: Double = 60,
        fat: Double = 10,
        fibre: Double? = nil,
        calories: Double? = nil,
        basis: FoodEstimate.Basis = .plate,
        servingGrams: Double? = nil
    ) -> FoodEstimate {
        FoodEstimate(
            name: name,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            fiberG: fibre,
            calories: calories,
            basis: basis,
            servingGrams: servingGrams
        )
    }

    @Test func aPlausibleReadingBecomesADraftEntry() throws {
        let proposal = try #require(estimate().proposal())

        #expect(proposal.name == "chicken and rice")
        #expect(proposal.proteinG == 40)
        #expect(proposal.carbsG == 60)
        #expect(proposal.fatG == 10)
    }

    /// The whole reason `proposal()` returns an optional: a model that says
    /// 1400 g of protein has not made a small error, and clamping it to 1000
    /// would hide that behind a number that looks survivable.
    @Test func anImpossibleMacroIsRefusedRatherThanClamped() {
        #expect(estimate(protein: 1400).proposal() == nil)
        #expect(estimate(carbs: -5).proposal() == nil)
        #expect(estimate(fat: 2000).proposal() == nil)
        #expect(estimate(fibre: 1001).proposal() == nil)
    }

    @Test func anImpossibleCalorieFigureIsRefused() {
        #expect(estimate(calories: 9000).proposal() == nil)
        #expect(estimate(calories: 600).proposal() != nil)
    }

    /// A packet figure is kept as one. `IntakeEntry` shows an entered figure
    /// and a derived figure side by side where they disagree, and that only
    /// works if what arrives here as a label reading stays one.
    @Test func aLabelFigureSurvivesAsAnEnteredCalorieCount() throws {
        let proposal = try #require(estimate(calories: 520).proposal())

        #expect(proposal.enteredCalories == 520)
        #expect(proposal.derivedCalories != 520)
    }

    @Test func anUnnamedReadingIsLeftUnnamed() throws {
        let proposal = try #require(estimate(name: "   ").proposal())

        // nil rather than "": the editor shows its own placeholder, and a name
        // of one space would defeat it.
        #expect(proposal.name == nil)
    }

    /// A photo of a table, or of something the model could not place, comes
    /// back as zeroes — which is a refusal, not a meal with no calories in it.
    @Test func aReadingWithNothingInItIsEmpty() {
        #expect(estimate(protein: 0, carbs: 0, fat: 0).isEmpty)
        #expect(!estimate(protein: 0, carbs: 0, fat: 0, calories: 300).isEmpty)
        #expect(!estimate().isEmpty)
    }

    // MARK: - Labels

    /// The bug this feature shipped with: a per-100 g column logged as though
    /// it were the meal. Thirty grams of the stuff is 30% of the column, and
    /// nothing here is estimated — it is the packet's own arithmetic.
    @Test func aPerHundredGramColumnScalesToWhatYouAte() throws {
        let label = estimate(protein: 20, carbs: 60, fat: 10, calories: 400, basis: .per100g)
        let had = label.scaled(toGrams: 30)

        #expect(had.proteinG == 6)
        #expect(had.carbsG == 18)
        #expect(had.fatG == 3)
        #expect(had.calories == 120)
    }

    @Test func aPerServingColumnScalesFromTheServingSize() throws {
        let label = estimate(protein: 10, carbs: 30, fat: 5, basis: .perServing, servingGrams: 45)

        #expect(label.scaled(toGrams: 90).proteinG == 20)
        #expect(label.scaled(toGrams: 45).proteinG == 10)
    }

    /// Once scaled it is a plate: a statement about what you ate, with no
    /// quantity still owed. Leaving it as a label would offer to scale it again.
    @Test func aScaledLabelIsNoLongerOwedAQuantity() {
        let had = estimate(basis: .per100g).scaled(toGrams: 50)

        #expect(had.basis == .plate)
        #expect(!had.basis.needsQuantity)
        #expect(had.servingGrams == nil)
    }

    @Test func onlyALabelIsOwedAQuantity() {
        #expect(!FoodEstimate.Basis.plate.needsQuantity)
        #expect(FoodEstimate.Basis.per100g.needsQuantity)
        #expect(FoodEstimate.Basis.perServing.needsQuantity)
    }

    /// A per-serving label with no serving size printed cannot be scaled by
    /// grams honestly, so it falls back to treating the column as 100 g rather
    /// than inventing a serving.
    @Test func aServingWithNoStatedSizeFallsBackRatherThanGuessing() {
        let label = estimate(protein: 10, basis: .perServing, servingGrams: nil)

        #expect(label.scaled(toGrams: 100).proteinG == 10)
    }
}
