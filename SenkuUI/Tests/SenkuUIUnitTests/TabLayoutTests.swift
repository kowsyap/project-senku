import Foundation
import Testing
@testable import SenkuUI

/// How many tabs a bar of a given width can carry.
///
/// The widths are the bar's, which is the screen less the 12 points of padding
/// either side it floats in.
@MainActor
@Suite struct TabLayoutTests {
    @Test func aMaxSizedPhoneCarriesFour() {
        // 440-point screen — 16 Pro Max, 17 Pro Max.
        #expect(TabLayout.slots(forBarWidth: 440 - 24) == 4)
    }

    @Test func aStandardPhoneCarriesThree() {
        // 402 points: 16 Pro, 17.
        #expect(TabLayout.slots(forBarWidth: 402 - 24) == 3)
        // 390: the 12, 13, 14, 15 and their Pros.
        #expect(TabLayout.slots(forBarWidth: 390 - 24) == 3)
        // 375: SE and the minis.
        #expect(TabLayout.slots(forBarWidth: 375 - 24) == 3)
    }

    /// A narrow split view on iPad should not produce a bar of one thing.
    @Test func itNeverFallsBelowTwo() {
        #expect(TabLayout.slots(forBarWidth: 200) == 2)
        #expect(TabLayout.slots(forBarWidth: 0) == 2)
    }

    /// Nor a bar wider than the choice is worth: five would leave nothing under
    /// More on a nine-screen app.
    @Test func itNeverGoesAboveFour() {
        #expect(TabLayout.slots(forBarWidth: 1200) == 4)
    }

    @Test func aStoredFourSurvivesUntilTheBarIsMeasured() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(["rest", "workout", "water", "food"], forKey: TabLayout.storageKey)

        // Before measuring: kept whole, because trimming against the default of
        // three would drop a tab a wide phone can carry and never restore it.
        let layout = TabLayout(defaults: defaults)
        #expect(layout.chosen.count == 4)

        layout.fit(barWidth: 440 - 24)
        #expect(layout.chosen.count == 4)
        #expect(layout.slots == 4)
    }

    @Test func aNarrowBarTrimsTheTail() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(["rest", "workout", "water", "food"], forKey: TabLayout.storageKey)

        let layout = TabLayout(defaults: defaults)
        layout.fit(barWidth: 390 - 24)

        #expect(layout.chosen == [.rest, .workout, .water])
    }

    @Test func toggleRespectsTheMeasuredCeiling() {
        let layout = TabLayout(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        layout.fit(barWidth: 390 - 24)      // three slots

        layout.toggle(.food)
        #expect(layout.chosen.count == 3)   // refused: full

        layout.toggle(.water)               // make room
        layout.toggle(.food)
        #expect(layout.chosen == [.rest, .workout, .food])
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
