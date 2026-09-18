import Foundation
import Testing
@testable import SenkuCore

@Suite struct AnimeTests {
    @Test func episodesComeFromTheSeasonsWhenThereAreSome() {
        let entry = AnimeEntry(
            title: "Vinland Saga",
            seasons: [
                AnimeSeason(number: 1, episodes: 24),
                AnimeSeason(number: 2, episodes: 24),
            ]
        )

        #expect(entry.isDetailed)
        #expect(entry.episodeCount == 48)
        #expect(entry.seasonCount == 2)
    }

    /// The other kind of memory: "about sixty episodes" and no more detail.
    @Test func episodesCanBeGivenAsOneNumber() {
        let entry = AnimeEntry(title: "Monster", totalEpisodes: 74, seasonCountOverride: 1)

        #expect(!entry.isDetailed)
        #expect(entry.episodeCount == 74)
        #expect(entry.seasonCount == 1)
    }

    /// Seasons win, so the two counts can never contradict each other.
    @Test func seasonDetailOverridesALooseTotal() {
        let entry = AnimeEntry(
            title: "Mob Psycho",
            seasons: [AnimeSeason(number: 1, episodes: 12)],
            totalEpisodes: 99
        )

        #expect(entry.episodeCount == 12)
    }

    @Test func searchLooksAtTitleAndGenre() {
        let entry = AnimeEntry(title: "Frieren", genres: ["Fantasy", "Adventure"])

        #expect(entry.matches("frie"))
        #expect(entry.matches("fantasy"))
        #expect(entry.matches(""))
        #expect(!entry.matches("horror"))
    }

    @Test func blankGenresAreDiscarded() {
        let entry = AnimeEntry(title: "Bebop", genres: ["  ", "Sci-fi", ""])
        #expect(entry.genres == ["Sci-fi"])
    }

    /// What you are watching now comes first; what you gave up on comes last.
    @Test func statusSortPutsAiringFirstAndDroppedLast() {
        let entries = [
            AnimeEntry(title: "B", status: .dropped),
            AnimeEntry(title: "A", status: .airing),
            AnimeEntry(title: "C", status: .pending),
        ]
        let sorted = AnimeSort.status.sort(entries)

        #expect(sorted.map(\.status) == [.airing, .pending, .dropped])
    }

    @Test func statusSortIsAlphabeticalWithinAGroup() {
        let entries = [
            AnimeEntry(title: "Zenshu", status: .airing),
            AnimeEntry(title: "Apothecary", status: .airing),
        ]

        #expect(AnimeSort.status.sort(entries).map(\.title) == ["Apothecary", "Zenshu"])
    }

    @Test func everyStatusSaysWhatItMeans() {
        for status in AnimeStatus.allCases {
            #expect(!status.title.isEmpty)
            #expect(!status.detail.isEmpty)
        }
    }
}

@Suite struct AnimeCompletenessTests {
    /// Stated with a finished status throughout: the counts are only required
    /// for something you have actually watched.
    @Test func aWatchedSeriesNeedsASeasonAndAnEpisode() {
        #expect(!AnimeEntry(title: "", status: .completed).isComplete)
        #expect(!AnimeEntry(title: "Bleach", status: .completed).isComplete)
        #expect(!AnimeEntry(title: "Bleach", status: .completed, seasonCountOverride: 1).isComplete)
        #expect(AnimeEntry(
            title: "Bleach",
            status: .completed,
            totalEpisodes: 366,
            seasonCountOverride: 16
        ).isComplete)
        #expect(AnimeEntry(
            title: "Bleach",
            status: .watched,
            seasons: [AnimeSeason(number: 1, episodes: 20)]
        ).isComplete)
    }

    /// A film is not a one-episode season, and should not have to pretend.
    @Test func aFilmNeedsOnlyATitle() {
        let film = AnimeEntry(title: "Your Name", isMovie: true)

        #expect(film.isComplete)
        #expect(film.countSummary == "Film")
    }

    @Test func totalsCountSeasonsAndEpisodesButNotFilms() {
        let totals = AnimeTotals([
            AnimeEntry(title: "A", seasons: [
                AnimeSeason(number: 1, episodes: 12),
                AnimeSeason(number: 2, episodes: 13),
            ]),
            AnimeEntry(title: "B", totalEpisodes: 26, seasonCountOverride: 2),
            AnimeEntry(title: "C", isMovie: true),
        ])

        #expect(totals.titles == 3)
        #expect(totals.series == 2)
        #expect(totals.movies == 1)
        #expect(totals.seasons == 4)
        #expect(totals.episodes == 51)
    }
}

@Suite struct CardioProtocolTests {
    private func ladder() -> CardioProtocol {
        CardioProtocol(
            exerciseID: "catalogue.cardio.treadmill",
            columns: ["Time", "Speed", "Incline"],
            rows: [
                ["5 (4)", "3 (4)", "0"],
                ["5 (4)", "5 (6)", "0"],
                ["2 (3)", "3 (4)", "11 (12)"],
                ["2 (3)", "5 (6)", "11 (12)"],
                ["3 (2)", "3 (4)", "0 (5)"],
                ["2 (2)", "5", "0 (8)"],
                ["1 (2)", "7", "0 (5)"],
            ]
        )
    }

    /// Time adds up; intensity does not — "39 mph" would be a number with no
    /// meaning behind it.
    @Test func timeIsSummedAndTheRestAreMaxed() {
        let totals = ladder().totals

        #expect(totals.count == 3)
        #expect(totals[0].column == "Time")
        #expect(totals[0].isSum)
        #expect(totals[0].value == 20)          // 5+5+2+2+3+2+1
        #expect(totals[1].value == 7)           // fastest block
        #expect(totals[2].value == 11)          // steepest block
    }

    /// The figure being done, not the one being worked towards.
    @Test func aCellIsReadAsItsFirstNumber() {
        #expect(CardioProtocol.number(in: "5 (4)") == 5)
        #expect(CardioProtocol.number(in: "12.5") == 12.5)
        #expect(CardioProtocol.number(in: "easy") == nil)
    }

    @Test func aColumnWithNoNumbersIsLeftOut() {
        let plan = CardioProtocol(
            exerciseID: "x",
            columns: ["Time", "Feel"],
            rows: [["5", "hard"], ["5", "easy"]]
        )

        #expect(plan.totals.map(\.column) == ["Time"])
    }

    @Test func totalsDropTheDecimalWhenThereIsNothingAfterIt() {
        let plan = CardioProtocol(exerciseID: "x", columns: ["Time"], rows: [["2.5"], ["2.5"]])
        #expect(plan.totals[0].text == "5")
    }
}

@Suite struct AnimeAiringTests {
    /// A show that started this week has an episode count nobody knows, and one
    /// you have only heard about has even less.
    @Test func airingAndPendingSeriesNeedOnlyATitle() {
        #expect(AnimeEntry(title: "Next season of something", status: .airing).isComplete)
        #expect(AnimeEntry(title: "Heard it was good", status: .pending).isComplete)
    }

    /// Finished, though, and you know how much of it there was.
    @Test func aFinishedSeriesStillNeedsItsCounts() {
        #expect(!AnimeEntry(title: "Done", status: .completed).isComplete)
        #expect(!AnimeEntry(title: "Gave up", status: .dropped).isComplete)
        #expect(AnimeEntry(title: "Done", status: .completed, totalEpisodes: 12, seasonCountOverride: 1).isComplete)
    }
}
