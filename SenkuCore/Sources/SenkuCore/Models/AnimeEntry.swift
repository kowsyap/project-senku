import Foundation

/// Where a series stands with you.
///
/// Five states, named as you asked for them. The pair worth being careful about
/// is **watched** and **completed**: watched means you have seen it, completed
/// means the series itself is finished and so are you. A show you are caught up
/// on but which is still releasing is `airing`, not either of them.
public enum AnimeStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending
    case airing
    case watched
    case completed
    case dropped

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pending: "Pending"
        case .airing: "Airing"
        case .watched: "Watched"
        case .completed: "Completed"
        case .dropped: "Dropped"
        }
    }

    /// What each one means, since two of them are close enough to need saying.
    public var detail: String {
        switch self {
        case .pending: "On the list, not started"
        case .airing: "Releasing now, keeping up"
        case .watched: "Seen it"
        case .completed: "Finished, and so is the series"
        case .dropped: "Gave up on it"
        }
    }

    public var symbol: String {
        switch self {
        case .pending: "clock"
        case .airing: "dot.radiowaves.left.and.right"
        case .watched: "eye.fill"
        case .completed: "checkmark.seal.fill"
        case .dropped: "xmark.circle"
        }
    }

    /// The order the list groups them in: what you are on now, then what is
    /// waiting, then what is behind you.
    public var rank: Int {
        switch self {
        case .airing: 0
        case .pending: 1
        case .watched: 2
        case .completed: 3
        case .dropped: 4
        }
    }
}

/// One season, and how many episodes are in it.
public struct AnimeSeason: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var number: Int
    /// Seasons often have names — "Shippuden", "Brotherhood" — and just as
    /// often do not.
    public var title: String
    public var episodes: Int

    public init(id: UUID = UUID(), number: Int, title: String = "", episodes: Int = 12) {
        self.id = id
        self.number = number
        self.title = title
        self.episodes = max(0, episodes)
    }

    public var name: String {
        title.isEmpty ? "Season \(number)" : "Season \(number) · \(title)"
    }
}

/// A series on the list.
///
/// ## Two ways to count episodes, because people have two kinds of memory
///
/// Some series you know season by season — three seasons of twelve, then one of
/// twenty-four. Others you only know as "sixty-something episodes", and being
/// made to invent a season breakdown to record that is the kind of friction
/// that stops a log being kept.
///
/// So both are allowed: fill in ``seasons`` and the total is computed, or leave
/// them empty and give ``totalEpisodes`` directly. ``episodeCount`` answers the
/// question either way, and nothing above this needs to know which was used.
public struct AnimeEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    /// Optional, and plural: a series is rarely one genre.
    public var genres: [String]
    public var status: AnimeStatus

    /// Season-by-season detail, when you have it.
    public var seasons: [AnimeSeason]

    /// The whole count, when you would rather not break it down. Ignored when
    /// `seasons` is non-empty, so the two can never disagree.
    public var totalEpisodes: Int?

    /// How many seasons there are, when no per-season detail was given.
    public var seasonCountOverride: Int?

    /// A film rather than a series: one sitting, no seasons to count.
    ///
    /// Without this the "at least one season and one episode" rule would be
    /// wrong for half of what people log — a film is not a one-episode season,
    /// and making someone type it as one is asking them to lie to the form.
    public var isMovie: Bool

    /// The poster, as a link.
    ///
    /// A URL rather than an uploaded file. Posters exist on the web already,
    /// and a link is a line of text: it costs nothing to store, it survives an
    /// export and re-import on another device, and it needs no photo-library
    /// permission to set. The cost is that it needs a network to draw, which is
    /// the right trade for a picture that is decoration rather than data.
    public var imageURL: String?

    public var note: String
    public var addedAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        genres: [String] = [],
        status: AnimeStatus = .pending,
        seasons: [AnimeSeason] = [],
        totalEpisodes: Int? = nil,
        seasonCountOverride: Int? = nil,
        isMovie: Bool = false,
        imageURL: String? = nil,
        note: String = "",
        addedAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.genres = genres.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        self.status = status
        self.seasons = seasons.sorted { $0.number < $1.number }
        self.totalEpisodes = totalEpisodes
        self.seasonCountOverride = seasonCountOverride
        self.isMovie = isMovie
        self.imageURL = imageURL?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? imageURL?.trimmingCharacters(in: .whitespaces)
            : nil
        self.note = note
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }

    /// The poster, if the link is one the app can actually load.
    public var posterURL: URL? {
        guard let imageURL, let url = URL(string: imageURL), url.scheme?.hasPrefix("http") == true else {
            return nil
        }
        return url
    }

    /// Whether the count is broken down by season.
    public var isDetailed: Bool { !seasons.isEmpty }

    /// Episodes in total, however they were recorded.
    public var episodeCount: Int? {
        if isDetailed { return seasons.reduce(0) { $0 + $1.episodes } }
        return totalEpisodes
    }

    public var seasonCount: Int? {
        isDetailed ? seasons.count : seasonCountOverride
    }

    /// Whether this can be saved: a title, and — unless it is a film, or still
    /// airing, or not started — at least one season with at least one episode.
    ///
    /// **Airing and pending are exempt.** A show that started this week has an
    /// episode count nobody knows yet, and one you have only heard about has
    /// even less; the rule existed to stop half-filled entries, not to make you
    /// invent numbers. The same is not true of something you have finished: if
    /// it is completed, dropped or watched, you know how much of it there was.
    ///
    /// Enforced here rather than in the form, so that an import cannot put a
    /// series on the list that the app would not have let you type.
    public var isComplete: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if isMovie || status == .airing || status == .pending { return true }
        return (seasonCount ?? 0) >= 1 && (episodeCount ?? 0) >= 1
    }

    /// "4 seasons · 97 episodes", or whichever half is known.
    public var countSummary: String {
        if isMovie { return "Film" }
        var parts: [String] = []
        if let seasons = seasonCount, seasons > 0 {
            parts.append("\(seasons) season\(seasons == 1 ? "" : "s")")
        }
        if let episodes = episodeCount, episodes > 0 {
            parts.append("\(episodes) episode\(episodes == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    /// Whether this series matches a search — by title or by genre, which is
    /// the same field doing both jobs because nobody wants to choose first.
    public func matches(_ search: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }

        if title.localizedCaseInsensitiveContains(query) { return true }
        return genres.contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

/// What the list adds up to.
public struct AnimeTotals: Hashable, Sendable {
    public var series: Int
    public var movies: Int
    public var seasons: Int
    public var episodes: Int

    public init(_ entries: [AnimeEntry]) {
        series = entries.filter { !$0.isMovie }.count
        movies = entries.filter(\.isMovie).count
        seasons = entries.reduce(0) { $0 + ($1.isMovie ? 0 : ($1.seasonCount ?? 0)) }
        // A film counts as one thing watched, not as an episode of anything.
        episodes = entries.reduce(0) { $0 + ($1.isMovie ? 0 : ($1.episodeCount ?? 0)) }
    }

    public var titles: Int { series + movies }
}

/// How the list is ordered.
public enum AnimeSort: String, CaseIterable, Identifiable, Sendable {
    case status
    case title
    case recentlyAdded
    case recentlyUpdated
    case episodes

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .status: "Status"
        case .title: "Title"
        case .recentlyAdded: "Recently added"
        case .recentlyUpdated: "Recently changed"
        case .episodes: "Episode count"
        }
    }

    public func sort(_ entries: [AnimeEntry]) -> [AnimeEntry] {
        switch self {
        case .status:
            // Within a status, alphabetical — otherwise the order inside each
            // group looks arbitrary, which is how a list stops being scannable.
            entries.sorted {
                $0.status.rank == $1.status.rank
                    ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    : $0.status.rank < $1.status.rank
            }
        case .title:
            entries.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .recentlyAdded:
            entries.sorted { $0.addedAt > $1.addedAt }
        case .recentlyUpdated:
            entries.sorted { $0.updatedAt > $1.updatedAt }
        case .episodes:
            entries.sorted { ($0.episodeCount ?? 0) > ($1.episodeCount ?? 0) }
        }
    }
}
