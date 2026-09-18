import Foundation
import SenkuCore

/// The little of the weight log a watch needs.
///
/// Sent instead of the log itself, deliberately. A watch screen shows the last
/// reading and the goal; shipping three years of weigh-ins across so it can
/// display two numbers would be a cost paid on every sync for nothing. When the
/// watch grows a chart of its own, this is where the shape of that payload gets
/// decided — and it will still not be "everything".
public struct WeightSummary: Codable, Hashable, Sendable {
    public var lastWeightKG: Double?
    public var lastLoggedAt: Date?
    public var trendKG: Double?
    public var goalWeightKG: Double?
    public var unitSystem: UnitSystem

    public init(
        lastWeightKG: Double? = nil,
        lastLoggedAt: Date? = nil,
        trendKG: Double? = nil,
        goalWeightKG: Double? = nil,
        unitSystem: UnitSystem = .metric
    ) {
        self.lastWeightKG = lastWeightKG
        self.lastLoggedAt = lastLoggedAt
        self.trendKG = trendKG
        self.goalWeightKG = goalWeightKG
        self.unitSystem = unitSystem
    }

    /// Built from what the phone holds, so the watch is never computing a trend
    /// from a slice of the history and quietly disagreeing with the phone.
    ///
    /// `lastWeightKG` is the newest weigh-in itself rather than its day's mean.
    /// The watch shows it as LAST and seeds its dial from it, and both of those
    /// are claims about the last number you entered.
    public init(log: WeightLogStore, profile: ProfileStore.Profile?) {
        let series = log.series
        self.lastWeightKG = log.weighIns.first?.weightKG
        self.lastLoggedAt = log.weighIns.first?.date
        self.trendKG = series.trendKG
        self.goalWeightKG = profile?.goalWeightKG
        self.unitSystem = profile?.unitSystem ?? .metric
    }
}
