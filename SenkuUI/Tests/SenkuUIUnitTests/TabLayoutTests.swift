import Foundation
import Testing
@testable import SenkuUI

/// How many tabs a bar of a given width can carry.
///
/// The widths are the screen's, in points.
@MainActor
@Suite struct TabLayoutTests {
    @Test func aMaxSizedPhoneCarriesFour() {
        // 440-point screen — 16 Pro Max, 17 Pro Max.
        #expect(TabLayout.slots(forScreenWidth: 440) == 4)
    }

    @Test func aStandardPhoneCarriesThree() {
        // 402 points: 16 Pro, 17.
        #expect(TabLayout.slots(forScreenWidth: 402) == 3)
        // 390: the 12, 13, 14, 15 and their Pros.
        #expect(TabLayout.slots(forScreenWidth: 390) == 3)
        // 375: SE and the minis.
        #expect(TabLayout.slots(forScreenWidth: 375) == 3)
    }

    /// A narrow split view on iPad should not produce a bar of one thing.
    @Test func itNeverFallsBelowTwo() {
        #expect(TabLayout.slots(forScreenWidth: 200) == 2)
        #expect(TabLayout.slots(forScreenWidth: 0) == 2)
    }

    /// Nor a bar wider than the choice is worth: five would leave nothing under
    /// More on a nine-screen app.
    @Test func itNeverGoesAboveFour() {
        #expect(TabLayout.slots(forScreenWidth: 1200) == 4)
    }

    @Test func aStoredFourSurvivesUntilTheBarIsMeasured() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(["rest", "workout", "water", "food"], forKey: TabLayout.storageKey)

        // Before measuring: kept whole, because trimming against the default of
        // three would drop a tab a wide phone can carry and never restore it.
        let layout = TabLayout(defaults: defaults)
        #expect(layout.chosen.count == 4)

        layout.fit(screenWidth: 440)
        #expect(layout.chosen.count == 4)
        #expect(layout.slots == 4)
    }

    @Test func aNarrowBarTrimsTheTail() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(["rest", "workout", "water", "food"], forKey: TabLayout.storageKey)

        let layout = TabLayout(defaults: defaults)
        layout.fit(screenWidth: 390)

        #expect(layout.chosen == [.rest, .workout, .water])
    }

    @Test func toggleRespectsTheMeasuredCeiling() {
        let layout = TabLayout(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        layout.fit(screenWidth: 390)      // three slots

        layout.toggle(.food)
        #expect(layout.chosen.count == 3)   // refused: full

        layout.toggle(.water)               // make room
        layout.toggle(.food)
        #expect(layout.chosen == [.rest, .workout, .food])
    }

    @Test func togglingMovesBetweenTheTwoLists() {
        let layout = TabLayout(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        layout.fit(screenWidth: 440)        // four slots

        #expect(layout.chosen == [.rest, .workout, .water])
        #expect(layout.others.contains(.food))

        layout.toggle(.food)
        #expect(layout.chosen == [.rest, .workout, .water, .food])
        #expect(!layout.others.contains(.food))

        layout.toggle(.rest)
        #expect(layout.chosen == [.workout, .water, .food])
        // Back to the front of More, where it is one tap away.
        #expect(layout.others.first == .rest)
    }

    /// The order is the bar's order, so ticking something must not re-sort what
    /// was already arranged.
    @Test func addingDoesNotReorderWhatIsThere() {
        let layout = TabLayout(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        layout.fit(screenWidth: 440)

        layout.moveInBar(from: IndexSet(integer: 2), to: 0)   // water first
        #expect(layout.chosen == [.water, .rest, .workout])

        layout.toggle(.anime)
        #expect(layout.chosen == [.water, .rest, .workout, .anime])
    }

    @Test func aReorderSurvivesBeingReopened() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!

        let first = TabLayout(defaults: defaults)
        first.fit(screenWidth: 440)
        first.moveInBar(from: IndexSet(integer: 0), to: 3)     // rest last
        first.moveInMore(from: IndexSet(integer: 0), to: 2)

        let second = TabLayout(defaults: defaults)
        #expect(second.chosen == first.chosen)
        #expect(second.others == first.others)
    }

    /// Trimming for a narrower screen must not lose a tab.
    @Test func overflowGoesToTheFrontOfMore() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(["rest", "workout", "water", "food"], forKey: TabLayout.storageKey)

        let layout = TabLayout(defaults: defaults)
        layout.fit(screenWidth: 390)

        #expect(layout.chosen == [.rest, .workout, .water])
        #expect(layout.others.first == .food)
    }

    /// A bar of "Me" and "More" is a menu with extra steps.
    @Test func theLastOneCannotBeRemoved() {
        let layout = TabLayout(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        layout.toggle(.rest)
        layout.toggle(.workout)
        layout.toggle(.water)

        #expect(layout.chosen.count == 1)
    }
}
