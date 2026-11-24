import Testing
@testable import SenkuUI

/// What the model says it could not tell is left off the screen, not shown as
/// an answer.
@Suite struct GarmentReadingTests {
    @Test func unknownsAreLeftOut() {
        #expect(GarmentReading.shown("Not visible") == nil)
        #expect(GarmentReading.shown(" not applicable ") == nil)
        #expect(GarmentReading.shown("") == nil)
        #expect(GarmentReading.shown("linen") == "linen")
        #expect(GarmentReading.shown(["navy", "unknown", " ", "white"]) == ["navy", "white"])
    }
}
