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

    /// The bug this was written for: 17.5 kg logged, "18 kg" shown.
    @Test func aHalfKiloIsNotRoundedAway() {
        #expect(Display.set(weightKG: 17.5, reps: 10, seconds: nil, in: .metric) == "17.5 kg×10")
        #expect(Display.set(weightKG: 18.75, reps: 10, seconds: nil, in: .metric) == "18.75 kg×10")
        #expect(Display.set(weightKG: 60, reps: 8, seconds: nil, in: .metric) == "60 kg×8")
    }

    /// Pounds are stored as kilograms; 45 lb has to come back as 45, not 45.01.
    @Test func poundsComeBackWhole() {
        let kg = Convert.kilograms(fromPounds: 45)
        #expect(Display.set(weightKG: kg, reps: 5, seconds: nil, in: .imperial) == "45 lb×5")
    }
}
