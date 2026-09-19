import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// The cross-process rules, which is the whole reason this store has a
/// `reload()`. Two stores over one suite of defaults stand in for the app and
/// the background launch that `PhoneSync` writes a watch weigh-in from.
@MainActor
@Suite struct WeightLogSharingTests {
    private let suite = UUID().uuidString

    private func store() -> WeightLogStore {
        WeightLogStore(defaults: UserDefaults(suiteName: suite)!)
    }

    private func weighIn(_ kg: Double, daysAgo: Int = 0) throws -> WeighIn {
        try WeighIn(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!,
            weightKG: kg,
            source: .manual
        )
    }

    /// The bug this store's `reload()` exists for: a weigh-in taken on the
    /// watch is written by a store the screen knows nothing about, and the
    /// screen's next weigh-in used to write its stale array back over it.
    @Test func aWeighInFromAnotherProcessSurvivesTheNextOneHere() throws {
        let onScreen = store()
        onScreen.add(try weighIn(80, daysAgo: 2))

        // The watch's, arriving through PhoneSync while no screen exists.
        store().add(try weighIn(79.5, daysAgo: 1))

        onScreen.add(try weighIn(79, daysAgo: 0))

        #expect(onScreen.weighIns.count == 3)
        #expect(onScreen.weighIns.contains { $0.weightKG == 79.5 })
    }

    @Test func deletingOneDoesNotTakeAnotherProcessesWithIt() throws {
        let onScreen = store()
        let mine = try weighIn(80, daysAgo: 2)
        onScreen.add(mine)

        store().add(try weighIn(79.5, daysAgo: 1))

        onScreen.delete(mine)

        #expect(onScreen.weighIns.count == 1)
        #expect(onScreen.weighIns.first?.weightKG == 79.5)
    }

    /// Swipe-to-delete hands over row positions. A reading arriving in between
    /// shifts every row under them, so the offsets are resolved to ids before
    /// anything is re-read — otherwise the wrong reading goes.
    @Test func swipingDeletesTheRowYouSwipedAndNotItsNeighbour() throws {
        let onScreen = store()
        onScreen.add(try weighIn(80, daysAgo: 3))
        onScreen.add(try weighIn(79, daysAgo: 2))

        // Newest first, so this lands at the top and pushes both rows down.
        store().add(try weighIn(78, daysAgo: 0))

        onScreen.delete(atOffsets: IndexSet(integer: 0))  // the 79, as displayed

        #expect(onScreen.weighIns.map(\.weightKG).sorted() == [78, 80])
    }

    /// The same record arriving twice — a message and its `transferUserInfo`
    /// fallback both getting through — must not become two readings.
    @Test func theSameWeighInTwiceIsStillOneWeighIn() throws {
        let onScreen = store()
        let fromTheWatch = try weighIn(79.5)

        onScreen.add(fromTheWatch)
        store().add(fromTheWatch)

        onScreen.reload()
        #expect(onScreen.weighIns.count == 1)
    }
}
