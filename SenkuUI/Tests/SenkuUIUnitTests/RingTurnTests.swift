import Foundation
import Testing
@testable import SenkuUI

/// The ring turns by the angle a finger sweeps round its centre. Screen
/// coordinates run downward, so clockwise is positive — the same direction the
/// ring's layout counts in.
@Suite struct RingTurnTests {
    private let centre = CGPoint(x: 200, y: 200)

    @Test func aQuarterTurnClockwiseIsPositive() {
        let turn = ExercisePicker.turn(from: CGPoint(x: 300, y: 200), to: CGPoint(x: 200, y: 300), around: centre)
        #expect(abs(turn - .pi / 2) < 1e-9)
    }

    /// Crossing the left-hand side — where the angle wraps from π to −π —
    /// is a small step, not most of a turn the other way.
    @Test func crossingTheWrapIsASmallStep() {
        let above = CGPoint(x: 100, y: 195)
        let below = CGPoint(x: 100, y: 205)
        let turn = ExercisePicker.turn(from: above, to: below, around: centre)
        #expect(turn < 0)
        #expect(abs(turn) < 0.2)
    }

    @Test func aFingerNearTheMiddleDoesNotTurnIt() {
        let turn = ExercisePicker.turn(from: CGPoint(x: 210, y: 200), to: CGPoint(x: 200, y: 210), around: centre)
        #expect(turn == 0)
    }
}
