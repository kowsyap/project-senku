import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// How one set reads back.
@Suite struct DisplaySetTests {
    /// The bug this was written for: a pull-up logged as "0 kg×12", which reads
    /// as a failed lift rather than twelve pull-ups.
    @Test func aBodyweightSetIsJustItsReps() {
        #expect(Display.set(weightKG: 0, reps: 12, seconds: nil, in: .metric) == "×12")
        #expect(Display.set(weightKG: 0, reps: 1, seconds: nil, in: .imperial) == "×1")
    }

    @Test func aLoadedSetKeepsItsWeight() {
        #expect(Display.set(weightKG: 60, reps: 8, seconds: nil, in: .metric).contains("×8"))
        #expect(Display.set(weightKG: 60, reps: 8, seconds: nil, in: .metric).hasPrefix("60"))
    }

    /// Added weight on a bodyweight movement is still weight, and still shown.
    @Test func aWeightedPullUpKeepsItsLoad() {
        let text = Display.set(weightKG: 20, reps: 6, seconds: nil, in: .metric)

        #expect(text.hasPrefix("20"))
        #expect(text.contains("×6"))
    }

    /// Holds already dropped a zero weight; this pins that they still do, since
    /// the reps branch now shares the rule. Sixty seconds reads as a clock
    /// rather than "60s" — the switch happens at a minute, not after it.
    @Test func anUnloadedHoldIsJustItsTime() {
        #expect(Display.set(weightKG: 0, reps: 0, seconds: 45, in: .metric) == "45s")
        #expect(Display.set(weightKG: 0, reps: 0, seconds: 90, in: .metric) == "1:30")
    }

    @Test func aLoadedHoldKeepsBoth() {
        let text = Display.set(weightKG: 10, reps: 0, seconds: 45, in: .metric)

        #expect(text.hasPrefix("+10"))
        #expect(text.contains("45s"))
    }
}
