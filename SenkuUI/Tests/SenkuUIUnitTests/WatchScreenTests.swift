import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// The watchlist split into screens: what each shows, and that making or
/// deleting one never strands a title.
@Suite struct WatchScreenTests {
    private func store() -> AnimeStore {
        AnimeStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test func withNoScreensItIsOneList() {
        let store = store()
        store.save(AnimeEntry(title: "Frieren"))

        #expect(store.list().count == 1)
        #expect(store.count() == 1)
    }

    /// Until now there was one list, and the first screen is it.
    @Test func theFirstScreenTakesEverything() throws {
        let store = store()
        store.save(AnimeEntry(title: "Frieren"))
        store.save(AnimeEntry(title: "Dune", isMovie: true))

        let anime = try #require(store.addScreen("Anime"))
        let films = try #require(store.addScreen("Films"))

        #expect(store.count(on: anime.id) == 2)
        #expect(store.count(on: films.id) == 0)
    }

    @Test func aTitleCanBeOnSeveralScreens() throws {
        let store = store()
        let hollywood = try #require(store.addScreen("Hollywood"))
        let marvel = try #require(store.addScreen("Marvel"))
        store.save(AnimeEntry(title: "Iron Man", isMovie: true, screens: [hollywood.id, marvel.id]))
        store.save(AnimeEntry(title: "Dune", isMovie: true, screens: [hollywood.id]))

        #expect(store.list(screen: hollywood.id, sort: .title).map(\.title) == ["Dune", "Iron Man"])
        #expect(store.list(screen: marvel.id).map(\.title) == ["Iron Man"])
        #expect(store.totals(on: marvel.id).movies == 1)
    }

    /// A title in no other collection lands in Other; one in another stays there.
    @Test func deletingACollectionLeavesItsOnlyTitlesInOther() throws {
        let store = store()
        let hollywood = try #require(store.addScreen("Hollywood"))
        let marvel = try #require(store.addScreen("Marvel"))
        store.save(AnimeEntry(title: "Thor", isMovie: true, screens: [marvel.id]))
        store.save(AnimeEntry(title: "Iron Man", isMovie: true, screens: [hollywood.id, marvel.id]))
        #expect(!store.hasOther)

        store.deleteScreen(marvel.id)

        #expect(store.list(screen: hollywood.id).map(\.title) == ["Iron Man"])
        #expect(store.list(screen: WatchScreen.other.id).map(\.title) == ["Thor"])
        #expect(store.choices.map(\.name) == ["Hollywood", "Other"])
    }

    /// Other is never in Adjust, and goes once it is empty.
    @Test func otherGoesOnceNothingIsInIt() throws {
        let store = store()
        let hollywood = try #require(store.addScreen("Hollywood"))
        let marvel = try #require(store.addScreen("Marvel"))
        store.save(AnimeEntry(title: "Thor", isMovie: true, screens: [marvel.id]))
        store.deleteScreen(marvel.id)

        var thor = try #require(store.entries.first)
        thor.screens = [hollywood.id]
        store.save(thor)

        #expect(!store.hasOther)
        #expect(store.screens.map(\.name) == ["Hollywood"])
        #expect(store.screen(WatchScreen.other.id) == nil)
    }

    @Test func deletingTheLastScreenMakesItOneListAgain() throws {
        let store = store()
        let anime = try #require(store.addScreen("Anime"))
        store.save(AnimeEntry(title: "Frieren", screens: [anime.id]))

        store.deleteScreen(anime.id)

        #expect(store.screens.isEmpty)
        #expect(store.entries.first?.screens == [])
        #expect(store.list().count == 1)
    }

    /// A list saved before screens existed still reads.
    @Test func anOlderEntryDecodesWithNoScreens() throws {
        let json = #"[{"id":"\#(UUID().uuidString)","title":"Naruto","genres":[],"status":"watched","seasons":[],"isMovie":false,"note":"","addedAt":0,"updatedAt":0}]"#
        let entries = try JSONDecoder().decode([AnimeEntry].self, from: Data(json.utf8))

        #expect(entries.first?.screens == [])
    }
}
