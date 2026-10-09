import Foundation

/// The sets and reps you are aiming for: "3 × 10", or a range, "3 × 8–12".
///
/// Three places can set one, most particular first: the exercise on a day of
/// the plan, then the plan as a whole, then ``standard``. Most programmes give
/// one figure for everything and an exercise only needs its own when it is
/// different — a heavy compound at 5 × 5 on a week of 3 × 10.
///
/// It decides two things. **Done**: the exercise is finished at `sets` sets.
/// **Heavier**: every one of those sets at one weight reached the top of the
/// range — 12, for 8–12 — and the next session opens a step up, back at the
/// bottom of the range.
public struct RepTarget: Codable, Hashable, Sendable {
    public var sets: Int
    /// The bottom of the range, or the only figure when there is no range.
    public var reps: Int
    /// The top of the range, when there is one.
    public var maxReps: Int?

    public static let standard = RepTarget(sets: 3, reps: 10)

    public static let setRange = 1...10
    public static let repRange = 1...50

    public init(sets: Int, reps: Int, maxReps: Int? = nil) {
        func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
            min(max(value, range.lowerBound), range.upperBound)
        }
        self.sets = clamp(sets, Self.setRange)
        self.reps = clamp(reps, Self.repRange)
        // A "range" of 10–10, or one upside down, is just the one figure.
        self.maxReps = maxReps
            .map { clamp($0, Self.repRange) }
            .flatMap { $0 > self.reps ? $0 : nil }
    }

    /// What every set has to reach for a step up.
    public var topReps: Int { maxReps ?? reps }

    public var isRange: Bool { maxReps != nil }

    /// "3 × 10" or "3 × 8–12".
    public var text: String {
        "\(sets) × " + (maxReps.map { "\(reps)–\($0)" } ?? "\(reps)")
    }

    private enum CodingKeys: String, CodingKey {
        case sets, reps, minReps, maxReps
    }

    /// Lenient for a file written by hand: `minReps` is read as `reps`, and the
    /// numbers go through the same clamping as the app's own.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sets = try container.decode(Int.self, forKey: .sets)
        let reps = try container.decodeIfPresent(Int.self, forKey: .reps)
            ?? container.decode(Int.self, forKey: .minReps)
        let maxReps = try container.decodeIfPresent(Int.self, forKey: .maxReps)
        self.init(sets: sets, reps: reps, maxReps: maxReps)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sets, forKey: .sets)
        try container.encode(reps, forKey: .reps)
        try container.encodeIfPresent(maxReps, forKey: .maxReps)
    }
}

extension WorkoutEntry {
    /// The weight this entry earned a step up from, if it did.
    ///
    /// Earned means the target was met *at one weight*: at least `target.sets`
    /// sets at the heaviest weight used, every one of them at the top of the
    /// range or more. Three sets of ten at 40 kg earns 3 × 10; 10, 10, 8 does
    /// not, and neither does 10, 10 at 40 with a third at 35 — dropping the
    /// weight to finish is the sign the weight is not yet yours. On 3 × 8–12,
    /// it takes three sets of twelve.
    ///
    /// Holds are left out: a plank gets longer, not heavier. A weight of zero is
    /// returned as zero — a bodyweight movement can earn a step up too, and it
    /// is the caller's business whether that step is a plate or another rep.
    public func earnedStepUp(for target: RepTarget) -> Double? {
        let counted = sets.filter { !$0.isTimed }
        guard let top = counted.map(\.weightKG).max() else { return nil }

        let atTop = counted.filter { abs($0.weightKG - top) < 0.01 }
        guard atTop.count >= target.sets,
              atTop.allSatisfy({ $0.reps >= target.topReps })
        else { return nil }

        return top
    }
}
