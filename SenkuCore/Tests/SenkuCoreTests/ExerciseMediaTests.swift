import Foundation
import Testing
@testable import SenkuCore

@Suite struct ExerciseMediaTests {
    private let media = ExerciseMedia.bundled
    private let catalogue = ExerciseCatalogue.bundled

    /// A renamed or removed catalogue exercise would leave a stale entry.
    @Test func everyEntryIsACatalogueExercise() {
        let ids = Set(catalogue.exercises.map(\.id))
        #expect(Set(media.exercises.keys).isSubset(of: ids))
    }

    @Test func everyEntryHasOneOrTwoPoses() {
        for (id, entry) in media.exercises {
            #expect((1...2).contains(entry.images.count), "\(id)")
            #expect(entry.images.allSatisfy { $0.hasPrefix("images/flat/") && $0.hasSuffix(".webp") }, "\(id)")
        }
    }

    @Test func urlsAreBuiltFromTheBase() {
        #expect(media.imageURLs(for: "catalogue.bench.flat").map(\.absoluteString) == [
            "https://exercise-dataset.com/images/flat/bench-press-start.webp",
            "https://exercise-dataset.com/images/flat/bench-press-peak.webp",
        ])
        #expect(media.pageURL(for: "catalogue.bench.flat")?.absoluteString
            == "https://exercise-dataset.com/exercise/bench-press/")
    }

    @Test func noMatchMeansNoPicture() {
        #expect(media.imageURLs(for: "catalogue.squat.sissy").isEmpty)
        #expect(media.imageURLs(for: "custom.whatever").isEmpty)
        #expect(media.pageURL(for: "custom.whatever") == nil)
    }
}
