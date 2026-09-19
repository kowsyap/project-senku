import Foundation
import Observation
import SenkuCore

/// Which plates your gym has, and what its bar weighs.
///
/// Stored per unit system rather than as one set: somebody who switches the app
/// from pounds to kilograms has not re-equipped their gym, and the plates they
/// described in pounds are still the plates on the rack. Keeping both means
/// switching back does not ask the same questions again.
@Observable
public final class PlateStore {
    static let storageKey = "senku.plates.v1"
    static let unitKey = "senku.plates.unit.v1"

    private let defaults: UserDefaults

    private var sets: [String: PlateSet] = [:]

    /// Which rack the calculator is working in.
    ///
    /// Its own setting rather than the profile's: plates are stamped in
    /// whatever the gym bought, and somebody who weighs themselves in pounds
    /// can still walk into a gym with kilo plates on the rack. Remembered,
    /// because that gym does not change between sessions.
    public var unit: UnitSystem {
        didSet {
            guard unit != oldValue else { return }
            defaults.set(unit.rawValue, forKey: Self.unitKey)
        }
    }

    /// - Parameter defaultUnit: What to start in when the calculator has never
    ///   been used — the profile's, normally. A unit chosen on the page itself
    ///   outranks it: that choice was made about a gym, and this one is a guess
    ///   from how you weigh yourself.
    public init(
        defaults: UserDefaults = SenkuStorage.shared,
        defaultUnit: UnitSystem? = nil
    ) {
        self.defaults = defaults
        self.unit = defaults.string(forKey: Self.unitKey).flatMap(UnitSystem.init(rawValue:))
            ?? defaultUnit
            ?? UnitPreference.current
        reload()
    }

    public func reload() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let stored = try? JSONDecoder().decode([String: PlateSet].self, from: data)
        else {
            sets = [:]
            return
        }
        sets = stored
    }

    public func set(for unit: UnitSystem) -> PlateSet {
        sets[unit.rawValue] ?? .standard(for: unit)
    }

    public func save(_ set: PlateSet) {
        sets[set.unit.rawValue] = set
        persist()
    }

    /// Back to what a commercial gym stocks.
    public func reset(for unit: UnitSystem) {
        sets[unit.rawValue] = nil
        persist()
    }

    /// Whether a denomination is on the rack.
    public func has(_ plate: Double, in unit: UnitSystem) -> Bool {
        set(for: unit).plates.contains { abs($0 - plate) < 0.001 }
    }

    /// Adds or removes one denomination. The largest plate cannot be removed —
    /// a rack with no big plates is not a gym anybody is describing, and an
    /// empty set would make every answer "you cannot build that".
    public func toggle(_ plate: Double, in unit: UnitSystem) {
        var current = set(for: unit)

        if has(plate, in: unit) {
            guard current.plates.count > 1 else { return }
            current.plates.removeAll { abs($0 - plate) < 0.001 }
        } else {
            current.plates.append(plate)
        }

        save(PlateSet(unit: unit, bar: current.bar, plates: current.plates))
    }

    public func setBar(_ bar: Double, in unit: UnitSystem) {
        let current = set(for: unit)
        save(PlateSet(unit: unit, bar: max(0, bar), plates: current.plates))
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(sets) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
