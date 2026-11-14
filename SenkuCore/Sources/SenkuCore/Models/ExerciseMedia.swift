import Foundation

/// Where to find pictures of a catalogue exercise — not the pictures.
///
/// The app ships only this map: Senku's exercise id to RepDB's, and the paths
/// of that exercise's poses (start and peak, or a single one for a hold). The
/// images stay on RepDB's site and are fetched when an exercise is opened, so
/// nothing of theirs is bundled or republished — their free tier allows use
/// inside an app with a credit, and not redistribution as a dataset.
///
/// Matches are the same exercise, or one that looks the same in a picture
/// (a chest dip for a triceps dip). Anything that would show a different path,
/// setup or machine has no entry, and simply has no picture.
public struct ExerciseMedia: Codable, Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        /// RepDB's id, for a link to its page.
        public let repdb: String
        /// Paths under `base`, in the order to show them.
        public let images: [String]
    }

    public let source: String
    /// The credit their licence asks for, shown wherever the pictures are.
    public let attribution: String
    public let base: URL
    public let exercises: [String: Entry]

    /// The poses of `exerciseID`, as full URLs: none for a custom exercise or
    /// one without a match.
    public func imageURLs(for exerciseID: String) -> [URL] {
        exercises[exerciseID]?.images.map { base.appending(path: $0) } ?? []
    }

    /// RepDB's page for the exercise.
    public func pageURL(for exerciseID: String) -> URL? {
        exercises[exerciseID].map { base.appending(path: "exercise/\($0.repdb)/") }
    }

    public static let bundled: ExerciseMedia = {
        guard let url = Bundle.module.url(forResource: "ExerciseMedia", withExtension: "json") else {
            preconditionFailure("ExerciseMedia.json is missing from the SenkuCore bundle")
        }
        do {
            return try JSONDecoder().decode(ExerciseMedia.self, from: Data(contentsOf: url))
        } catch {
            preconditionFailure("ExerciseMedia.json could not be decoded: \(error)")
        }
    }()
}
