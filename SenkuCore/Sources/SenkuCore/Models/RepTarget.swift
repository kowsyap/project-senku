import Foundation

/// The sets and reps you are aiming for on every exercise.
///
/// One target for the whole plan rather than one per exercise. Per exercise is
/// more precise and is a screen of numbers to fill in before the first
/// workout; one figure is right for most lifts, and it is the figure most
/// programmes give.
public struct RepTarget: Codable, Hashable, Sendable {
    public var sets: Int
    public var reps: Int

    public static let standard = RepTarget(sets: 3, reps: 10)

    public static let setRange = 1...10
    public static let repRange = 1...50

    public init(sets: Int, reps: Int) {
        self.sets = min(max(sets, Self.setRange.lowerBound), Self.setRange.upperBound)
        self.reps = min(max(reps, Self.repRange.lowerBound), Self.repRange.upperBound)
    }
}

extension WorkoutEntry {
    /// The weight this entry earned a step up from, if it did.
    ///
    /// Earned means the target was met *at one weight*: at least `target.sets`
    /// sets at the heaviest weight used, every one of them at `target.reps` or
    /// more. Three sets of ten at 40 kg earns it; 10, 10, 8 does not, and
    /// neither does 10, 10 at 40 with a third at 35 — dropping the weight to
    /// finish is the sign the weight is not yet yours.
    ///
    /// Holds are left out: a plank gets longer, not heavier. A weight of zero is
    /// returned as zero — a bodyweight movement can earn a step up too, and it
    /// is the caller's business whether that step is a plate or another rep.
    public func earnedStepUp(for target: RepTarget) -> Double? {
        let counted = sets.filter { !$0.isTimed }
        guard let top = counted.map(\.weightKG).max() else { return nil }

        let atTop = counted.filter { abs($0.weightKG - top) < 0.01 }
        guard atTop.count >= target.sets,
              atTop.allSatisfy({ $0.reps >= target.reps })
        else { return nil }

        return top
    }
}
