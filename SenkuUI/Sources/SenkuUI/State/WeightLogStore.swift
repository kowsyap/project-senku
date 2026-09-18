import Foundation
import Observation
import SenkuCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Every weigh-in, kept.
///
/// ## Why `UserDefaults` and not SwiftData yet
///
/// [REQUIREMENTS.md](../../../../docs/REQUIREMENTS.md) names SwiftData as the
/// home for history, and it still is. This is not that: it is a JSON array in
/// the App Group container, the same shape `ProfileStore` already uses, chosen
/// so the first useful weight screen does not wait on a storage migration that
/// touches every future feature.
///
/// The cost is bounded and worth naming: a few thousand weigh-ins encode and
/// decode in one go on every change, which is fine for one reading a day for
/// years and would not be fine for a workout log. The repository shape here —
/// load, add, delete, and a `WeightSeries` for everything derived — is the seam
/// to swap when the real store arrives, and nothing above it needs to change.
@Observable
public final class WeightLogStore {
    static let storageKey = "senku.weightLog.v1"
    static let seededKey = "senku.weightLog.seeded.v1"

    private let defaults: UserDefaults

    /// Newest first, which is the order the list wants and the reverse of the
    /// order the maths wants. ``series`` sorts for itself.
    public private(set) var weighIns: [WeighIn] = []

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.weighIns = Self.load(from: defaults)
    }

    /// Everything derived — trend, weekly rate, time to a goal — comes from
    /// here rather than from stored fields, so none of it can go stale.
    public var series: WeightSeries { WeightSeries(weighIns) }

    /// Starts the log at the weight the profile already knows.
    ///
    /// The profile holds a weight and the date it was saved, which is a real
    /// weigh-in that happened — asking for it again to draw the first point of
    /// a chart would be asking a question the app already has the answer to.
    /// It is recorded as `.imported` rather than `.manual`, because the app
    /// does not blur a number you typed on a scale with one it carried over.
    ///
    /// Once only: the flag persists, so deleting every reading leaves the log
    /// genuinely empty instead of quietly resurrecting the profile's weight.
    @discardableResult
    public func seedFromProfileIfNeeded(_ profile: ProfileStore.Profile?) -> Bool {
        guard let profile,
              weighIns.isEmpty,
              !defaults.bool(forKey: Self.seededKey),
              let seed = try? WeighIn(
                  date: profile.updatedAt,
                  weightKG: profile.metrics.weightKG,
                  source: .imported,
                  note: "From your profile"
              )
        else { return false }

        defaults.set(true, forKey: Self.seededKey)
        add(seed)
        return true
    }

    public func add(_ weighIn: WeighIn) {
        weighIns.append(weighIn)
        weighIns.sort { $0.date > $1.date }
        persist()
    }

    public func delete(_ weighIn: WeighIn) {
        weighIns.removeAll { $0.id == weighIn.id }
        persist()
    }

    public func delete(atOffsets offsets: IndexSet) {
        weighIns.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(weighIns) else { return }
        defaults.set(data, forKey: Self.storageKey)

        // The widget shows the last reading and the trend, both of which have
        // just changed.
        #if canImport(WidgetKit) && !os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private static func load(from defaults: UserDefaults) -> [WeighIn] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WeighIn].self, from: data)
        else { return [] }
        return decoded.sorted { $0.date > $1.date }
    }
}
