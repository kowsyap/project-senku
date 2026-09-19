import Foundation
import SenkuCore

/// What a gym actually owns, in the units its plates are stamped in.
///
/// ## Why the plates are not stored in kilograms
///
/// A 45 lb plate is 20.41166 kg. Convert the inventory and every figure on the
/// screen inherits that fuzz — "20.4 + 20.4 + 4.5 a side" is an answer to a
/// question nobody asked. So the set carries its own unit, the arithmetic is
/// done in it, and conversion happens once at the boundary where the logged
/// weight (always kilograms) comes in and goes out.
public struct PlateSet: Codable, Hashable, Sendable {
    public var unit: UnitSystem
    /// The empty bar, in `unit`.
    public var bar: Double
    /// One of each denomination the gym has, largest first. Pairs are assumed:
    /// a plate you cannot match on the other side is not a plate you can load.
    public var plates: [Double]

    public init(unit: UnitSystem, bar: Double, plates: [Double]) {
        self.unit = unit
        self.bar = bar
        self.plates = plates.sorted(by: >)
    }

    /// The bars a gym actually has, with what they weigh.
    ///
    /// Named rather than typed, because nobody thinks "twenty kilograms" —
    /// they think "the women's bar". The weights are the standard ones; a gym
    /// with something odd can still type a number.
    public struct Bar: Hashable, Sendable, Identifiable {
        public let name: String
        public let pounds: Double
        public let kilograms: Double

        public var id: String { name }

        public func weight(in unit: UnitSystem) -> Double {
            unit == .imperial ? pounds : kilograms
        }
    }

    public static let bars: [Bar] = [
        Bar(name: "Olympic", pounds: 45, kilograms: 20),
        Bar(name: "Women's Olympic", pounds: 35, kilograms: 15),
        Bar(name: "Trap / hex", pounds: 60, kilograms: 25),
        Bar(name: "Safety squat", pounds: 65, kilograms: 30),
        Bar(name: "EZ curl", pounds: 25, kilograms: 10),
        Bar(name: "Technique", pounds: 15, kilograms: 7),
        Bar(name: "Smith machine", pounds: 15, kilograms: 7),
    ]

    /// The named bar this set's weight matches, if any.
    public var namedBar: Bar? {
        Self.bars.first { abs($0.weight(in: unit) - bar) < 0.01 }
    }

    /// An Olympic bar and the plates a commercial gym stocks.
    public static let pounds = PlateSet(unit: .imperial, bar: 45, plates: [45, 35, 25, 10, 5, 2.5])
    public static let kilograms = PlateSet(unit: .metric, bar: 20, plates: [25, 20, 15, 10, 5, 2.5, 1.25])

    public static func standard(for unit: UnitSystem) -> PlateSet {
        unit == .imperial ? .pounds : .kilograms
    }

    /// The smallest change that can be made to the bar: twice the smallest
    /// plate, because plates go on in pairs. This is the figure that decides
    /// whether a five-pound progression is even possible.
    public var smallestStep: Double { (plates.last ?? 0) * 2 }

    /// The nearest weight this rack can actually build, rounding towards
    /// whichever side is closer.
    ///
    /// Everything loadable is the bar plus some multiple of the smallest step,
    /// since every plate a gym stocks is a multiple of its smallest — so
    /// snapping is arithmetic rather than a search. 227 on a pound rack is 225,
    /// and stepping up from there gives 230 rather than 232.
    public func snapped(_ weight: Double) -> Double {
        guard smallestStep > 0 else { return weight }
        let steps = ((weight - bar) / smallestStep).rounded()
        return max(bar, bar + steps * smallestStep)
    }
}

/// What to hang on one side, and what that actually comes to.
public struct PlateLoad: Hashable, Sendable {
    /// One side of the bar, largest plate first.
    public let perSide: [Double]
    /// What the loaded bar weighs, in the set's unit.
    public let total: Double
    /// What was asked for, in the set's unit.
    public let target: Double
    public let unit: UnitSystem

    /// Whether the bar can be built to the weight asked for.
    public var isExact: Bool { abs(total - target) < 0.01 }

    /// True when the target is below the empty bar — which is not a loading
    /// problem, it is a different exercise.
    public var isUnderBar: Bool { target < 0 }

    /// "45 · 25 · 10", or an empty string for a bare bar.
    public var description: String {
        perSide.map { Self.trim($0) }.joined(separator: " · ")
    }

    static func trim(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

/// Which plates make up a weight.
///
/// ## Why this exists at all
///
/// The arithmetic is not hard. It is just badly timed: it happens between sets,
/// warm, with the next lift on the clock, and it happens four or five times on
/// the way up to a working weight. The stops everyone knows cold — 135, 225,
/// 315 — are the pure-45 ones; everything in between is where people stop and
/// count.
///
/// The more useful half is the second answer: **whether the number is loadable
/// at all**. A gym with no 2.5s cannot build 190, and finding that out with a
/// bar on your back is worse than being told at the rack.
public enum PlateMath {
    /// Largest plate first until nothing more fits.
    ///
    /// Greedy, which is optimal for every plate set a gym actually stocks —
    /// each denomination divides into the next, so taking the biggest plate
    /// that fits can never strand a remainder a smaller combination would have
    /// covered. A set of 7s and 3s would break that, and no gym has one.
    public static func load(target: Double, using set: PlateSet) -> PlateLoad {
        let perSideTarget = (target - set.bar) / 2

        guard perSideTarget > 0 else {
            return PlateLoad(
                perSide: [],
                total: set.bar,
                target: target,
                unit: set.unit
            )
        }

        var remaining = perSideTarget
        var chosen: [Double] = []

        for plate in set.plates {
            // A hair of slack, so a target that is exactly reachable is not
            // refused by floating-point arithmetic a thousandth short.
            while remaining + 0.0001 >= plate {
                chosen.append(plate)
                remaining -= plate
            }
        }

        let loaded = chosen.reduce(0, +)
        return PlateLoad(
            perSide: chosen,
            total: set.bar + loaded * 2,
            target: target,
            unit: set.unit
        )
    }

    /// The same, from a weight in kilograms — which is how the app stores every
    /// lift, whatever the plates say.
    public static func load(kilograms: Double, using set: PlateSet) -> PlateLoad {
        let target = set.unit == .imperial
            ? Convert.pounds(fromKilograms: kilograms)
            : kilograms

        // Rounded to a tenth first: 102.5 kg comes back from a pounds round
        // trip as 102.49999, and a bar that cannot quite be built because of
        // the third decimal place is a bug pretending to be advice.
        return load(target: (target * 10).rounded() / 10, using: set)
    }
}
