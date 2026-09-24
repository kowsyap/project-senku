import Foundation
import Testing
@testable import SenkuUI

/// The envelope Gemini answers in, which was read off documentation rather
/// than observed. These pin the shape so a change to it fails here rather than
/// in somebody's kitchen.
@Suite struct GeminiResponseTests {
    private func envelope(_ payload: String, type: String = "model_output") -> Data {
        Data("""
        {
          "id": "v1_abc",
          "model": "gemini-3.8-flash",
          "status": "completed",
          "steps": [
            {"type": "\(type)", "content": [{"type": "text", "text": \(payload)}]}
          ]
        }
        """.utf8)
    }

    private let panel = #"""
    "{\"name\":\"canned tuna\",\"proteinG\":22,\"carbsG\":0,\"fatG\":7,\"fiberG\":0,\"labelCalories\":150,\"basis\":\"perServing\",\"servingGrams\":85}"
    """#

    @Test func aPanelReadingComesBackWhole() throws {
        let estimate = try GeminiResponse.estimate(from: envelope(panel))

        #expect(estimate.name == "canned tuna")
        #expect(estimate.proteinG == 22)
        #expect(estimate.fatG == 7)
        #expect(estimate.calories == 150)
        #expect(estimate.basis == .perServing)
        #expect(estimate.servingGrams == 85)
    }

    /// Zero means absent, the same as on the on-device path — the two readers
    /// have to agree about this or the editor behaves differently depending on
    /// a setting nobody can see from there.
    @Test func zeroIsAbsenceNotAReading() throws {
        let payload = #"""
        "{\"name\":\"rice\",\"proteinG\":4,\"carbsG\":45,\"fatG\":1,\"fiberG\":0,\"labelCalories\":0,\"basis\":\"plate\",\"servingGrams\":0}"
        """#
        let estimate = try GeminiResponse.estimate(from: envelope(payload))

        #expect(estimate.fiberG == nil)
        #expect(estimate.calories == nil)
        #expect(estimate.servingGrams == nil)
    }

    /// A basis Gemini invented falls back to `.plate`, the cautious end: a
    /// plate is shown as an estimate to correct, where a wrongly-claimed label
    /// would be presented as exact and then scaled.
    @Test func anUnknownBasisFallsBackToPlate() throws {
        let payload = #"""
        "{\"name\":\"x\",\"proteinG\":1,\"carbsG\":1,\"fatG\":1,\"fiberG\":0,\"labelCalories\":0,\"basis\":\"perOunce\",\"servingGrams\":0}"
        """#
        #expect(try GeminiResponse.estimate(from: envelope(payload)).basis == .plate)
    }

    /// The text is found by step type, not by position — a response carrying
    /// steps this app does not care about must not shift the answer.
    @Test func theOutputStepIsFoundByTypeNotIndex() throws {
        let data = Data("""
        {
          "steps": [
            {"type": "thinking", "content": [{"type": "text", "text": "hmm"}]},
            {"type": "model_output", "content": [{"type": "text", "text": \(panel)}]}
          ]
        }
        """.utf8)

        #expect(try GeminiResponse.estimate(from: data).proteinG == 22)
    }

    @Test func rubbishIsRefusedRatherThanGuessedAt() {
        #expect(throws: GeminiFailure.malformedResponse) {
            try GeminiResponse.estimate(from: Data("not json".utf8))
        }
        #expect(throws: GeminiFailure.malformedResponse) {
            try GeminiResponse.estimate(from: Data(#"{"steps":[]}"#.utf8))
        }
        #expect(throws: GeminiFailure.malformedResponse) {
            try GeminiResponse.estimate(from: envelope(#""not the json we asked for""#))
        }
    }
}
