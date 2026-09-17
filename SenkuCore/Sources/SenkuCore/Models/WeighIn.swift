import Foundation

/// A single time the user stood on a scale.
///
/// Deliberately thin: a weight, when it was taken, and where it came from.
/// Everything interesting — the trend, the rate, what it implies about
/// maintenance — is computed in ``WeightSeries`` from a collection of these, so
/// nothing derived is ever stored and nothing stored can go stale.
public struct WeighIn: Hashable, Codable, Sendable, Identifiable {
    /// Where the number came from. Kept because the app's rule is that a
    /// measured figure and an imported one are not silently the same thing.
    public enum Source: String, Hashable, Codable, Sendable {
        case manual
        case healthKit
        case imported
    }

    public let id: UUID
    public var date: Date
    public var weightKG: Double
    public var source: Source
    public var note: String?

    public init(
        id: UUID = UUID(),
        date: Date,
        weightKG: Double,
        source: Source = .manual,
        note: String? = nil
    ) throws {
        guard BodyMetrics.allowedWeightKG.contains(weightKG) else {
            throw ValidationError.weightOutOfRange(weightKG)
        }
        self.id = id
        self.date = date
        self.weightKG = weightKG
        self.source = source
        self.note = note
    }
}

/// A run of weigh-ins, and what can honestly be said from them.
///
/// ## Why a trend rather than the last reading
///
/// Day-to-day body weight is mostly water, food in transit and glycogen; the
/// signal underneath is a fraction of the noise on top. Reacting to the last
/// number on the scale is how someone on a perfectly good plan concludes it has
/// stopped working. So the headline figure here is an **exponentially weighted
/// moving average** with a seven-day half-life: recent days count most, no day
/// is ignored, and one heavy dinner cannot move it far.
///
/// The half-life is stated rather than hidden because the app names its
/// methods — see ``smoothingHalfLifeDays``.
public struct WeightSeries: Sendable {
    /// Days for the weight of a reading to halve. Seven is long enough to
    /// swallow a weekend and short enough to turn within a fortnight.
    public static let smoothingHalfLifeDays: Double = 7

    /// One value per day, oldest first. Several weigh-ins in a day are averaged
    /// rather than refused: weighing twice is noise, but throwing away what
    /// someone recorded is worse than absorbing it.
    public let dailyValues: [(day: Date, weightKG: Double)]

    private let calendar: Calendar

    public init(_ weighIns: [WeighIn], calendar: Calendar = .current) {
        self.calendar = calendar

        let grouped = Dictionary(grouping: weighIns) { calendar.startOfDay(for: $0.date) }
        self.dailyValues = grouped
            .map { day, entries in
                (day: day, weightKG: entries.reduce(0) { $0 + $1.weightKG } / Double(entries.count))
            }
            .sorted { $0.day < $1.day }
    }

    public var isEmpty: Bool { dailyValues.isEmpty }

    /// The smoothed weight as of the most recent day with a reading.
    ///
    /// Gaps are respected: the decay is applied over *elapsed days*, not over
    /// the number of entries, so a fortnight away does not let a stale value
    /// keep its weight as though it were yesterday's.
    public var trendKG: Double? { trendValues.last?.weightKG }

    /// The trend as it stood on each day with a reading, oldest first.
    ///
    /// The same exponential smoothing as ``trendKG`` — which is the last value
    /// of this — kept as a series so a chart can draw the line the app claims
    /// to be following, beside the readings it is drawn from. Showing only the
    /// final figure would be asking to be taken on trust.
    public var trendValues: [(day: Date, weightKG: Double)] {
        guard let first = dailyValues.first else { return [] }

        let decayPerDay = pow(0.5, 1 / Self.smoothingHalfLifeDays)
        var trend = first.weightKG
        var previousDay = first.day
        var series = [(day: first.day, weightKG: trend)]

        for entry in dailyValues.dropFirst() {
            let gap = max(0, entry.day.timeIntervalSince(previousDay) / 86_400)
            let weight = pow(decayPerDay, gap)
            trend = trend * weight + entry.weightKG * (1 - weight)
            previousDay = entry.day
            series.append((day: entry.day, weightKG: trend))
        }
        return series
    }

    /// The most recent reading, which is what the user last saw on the scale.
    public var latest: (day: Date, weightKG: Double)? { dailyValues.last }

    /// Days between the first and last reading.
    public var spanDays: Double {
        guard let first = dailyValues.first, let last = dailyValues.last else { return 0 }
        return last.day.timeIntervalSince(first.day) / 86_400
    }

    /// Observed change per week, measured by least squares across every daily
    /// value rather than from the endpoints.
    ///
    /// Endpoints are the tempting implementation and the wrong one: they hand
    /// the whole answer to two readings, either of which can be the day after a
    /// large meal. A regression uses all of them.
    public var weeklyChangeKG: Double? {
        guard dailyValues.count >= 2, spanDays > 0 else { return nil }

        let xs = dailyValues.map { $0.day.timeIntervalSince(dailyValues[0].day) / 86_400 }
        let ys = dailyValues.map(\.weightKG)
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n

        var covariance = 0.0
        var variance = 0.0
        for (x, y) in zip(xs, ys) {
            covariance += (x - meanX) * (y - meanY)
            variance += (x - meanX) * (x - meanX)
        }
        guard variance > 0 else { return nil }

        return covariance / variance * 7
    }
}
