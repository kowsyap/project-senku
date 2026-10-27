import Foundation
import Testing
@testable import SenkuCore
@testable import SenkuUI

/// Dues and the watchlist as extras: in by default, nowhere once removed, and
/// their data gone with them.
@MainActor
@Suite struct ExtrasTests {
    private func fresh() -> UserDefaults { UserDefaults(suiteName: UUID().uuidString)! }

    private func data(_ defaults: UserDefaults) -> ExtraData {
        ExtraData(
            dues: DueDateStore(defaults: defaults),
            anime: AnimeStore(defaults: defaults)
        )
    }

    /// Every phone from before extras existed keeps both.
    @Test func nothingStoredMeansBothAreIn() {
        let defaults = fresh()

        #expect(ExtraStore(defaults: defaults).installed == [.dues, .watchlist])
        #expect(TabLayout(defaults: defaults).others.contains(.dueDates))
        #expect(TabLayout(defaults: defaults).others.contains(.anime))
    }

    @Test func aRemovedExtraIsNowhere() {
        let defaults = fresh()
        let extras = ExtraStore(defaults: defaults)
        let layout = TabLayout(defaults: defaults)

        layout.drop(.dueDates)
        extras.remove(.dues, data: data(defaults))

        let reopened = TabLayout(defaults: defaults)
        #expect(!reopened.chosen.contains(.dueDates))
        #expect(!reopened.others.contains(.dueDates))
        #expect(!ExtraStore(defaults: defaults).isInstalled(.dues))
        #expect(ExtraStore(defaults: defaults).isInstalled(.watchlist))
    }

    @Test func addingBackGoesToMoreWhenTheBarIsFull() {
        let defaults = fresh()
        let extras = ExtraStore(defaults: defaults)
        let layout = TabLayout(defaults: defaults)
        layout.drop(.anime)
        extras.remove(.watchlist, data: data(defaults))

        extras.install(.watchlist)
        layout.add(.anime)

        #expect(layout.others.first == .anime)
        #expect(TabLayout(defaults: defaults).others.first == .anime)
    }

    @Test func removingDeletesTheWatchlistAndItsScreens() {
        let defaults = fresh()
        let stores = data(defaults)
        stores.anime.addScreen("Anime")
        stores.anime.save(AnimeEntry(title: "Frieren"))
        #expect(Extra.watchlist.hasData(in: stores))

        ExtraStore(defaults: defaults).remove(.watchlist, data: stores)

        #expect(!Extra.watchlist.hasData(in: stores))
        #expect(AnimeStore(defaults: defaults).entries.isEmpty)
        #expect(AnimeStore(defaults: defaults).screens.isEmpty)
    }

    /// The saved file is a backup holding only the watchlist, so Import Data
    /// takes it back.
    @Test func theSavedFileReadsBackAsABackup() throws {
        let stores = data(fresh())
        let screen = try #require(stores.anime.addScreen("Anime"))
        stores.anime.save(AnimeEntry(title: "Frieren", screens: [screen.id]))

        let url = try Extra.watchlist.export(from: stores)
        let document = try SenkuImportDocument.decode(Data(contentsOf: url))

        #expect(document.anime?.map(\.title) == ["Frieren"])
        #expect(document.watchlistScreens?.map(\.name) == ["Anime"])
        #expect(document.dueDates == nil)
        #expect(document.profile == nil)
    }
}
