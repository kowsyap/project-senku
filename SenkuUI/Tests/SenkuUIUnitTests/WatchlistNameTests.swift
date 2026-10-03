import Foundation
import Testing
@testable import SenkuUI

@MainActor
@Suite struct WatchlistNameTests {
    private func fresh() -> UserDefaults {
        let suite = "senku.tests.watchlist.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func startsAsWatchlist() {
        #expect(WatchlistName(defaults: fresh()).title == "Watchlist")
    }

    @Test func aNameIsKeptAndReadBack() {
        let defaults = fresh()
        WatchlistName(defaults: defaults).name = "K-dramas"

        #expect(WatchlistName(defaults: defaults).title == "K-dramas")
        #expect(WatchlistName.current(in: defaults) == "K-dramas")
    }

    /// A tab with no name is a tab you cannot find.
    @Test func aBlankNameFallsBack() {
        let defaults = fresh()
        let list = WatchlistName(defaults: defaults)
        list.name = "   "

        #expect(list.title == "Watchlist")
        #expect(WatchlistName.current(in: defaults) == "Watchlist")
    }

    @Test func aLongNameIsCutToFitTheBar() {
        let list = WatchlistName(defaults: fresh())
        list.name = String(repeating: "a", count: 40)
        #expect(list.name.count == WatchlistName.maxLength)
    }
}
