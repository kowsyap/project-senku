#if !os(watchOS)
import Foundation

/// Unpacking what Gemini sends back.
///
/// Its own file, and deliberately free of UIKit, so that the part most likely
/// to be wrong can be tested on the host without a phone. The envelope shape
/// here was read off Google's documentation rather than observed from a live
/// call, which is exactly the kind of thing that is right until it is not.
/// What can go wrong on the way to and from Google.
enum GeminiFailure: Error, Equatable {
    case noKey
    /// The key was refused. Worth its own case: it is the one failure the
    /// person can actually fix, and it should not read as "bad photo".
    case unauthorized
    case rateLimited
    /// Google is overloaded. Transient, and worth saying so — it is not the
    /// photograph, the key, or anything the person did.
    case busy
    case http(Int)
    case malformedResponse
}

enum GeminiResponse {
    /// Digs the model's JSON out of the envelope it arrives in.
    ///
    /// The text lives at `steps[].content[].text`, and the step that holds it
    /// is found by type rather than by index — a response may carry steps this
    /// app does not care about, and counting on position is how that breaks
    /// quietly later.
    static func estimate(from data: Data) throws -> FoodEstimate {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let steps = root["steps"] as? [[String: Any]]
        else { throw GeminiFailure.malformedResponse }

        let text = steps
            .filter { ($0["type"] as? String) == "model_output" }
            .compactMap { $0["content"] as? [[String: Any]] }
            .flatMap { $0 }
            .first { ($0["type"] as? String) == "text" }?["text"] as? String

        guard
            let text,
            let payload = try? JSONDecoder().decode(Payload.self, from: Data(text.utf8))
        else { throw GeminiFailure.malformedResponse }

        return payload.estimate
    }

    // MARK: - Shapes

    struct Payload: Decodable {
        var name: String
        var proteinG: Double
        var carbsG: Double
        var fatG: Double
        var fiberG: Double
        var labelCalories: Double
        var basis: String
        var servingGrams: Double

        var estimate: FoodEstimate {
            FoodEstimate(
                name: name,
                proteinG: proteinG,
                carbsG: carbsG,
                fatG: fatG,
                fiberG: fiberG > 0 ? fiberG : nil,
                calories: labelCalories > 0 ? labelCalories : nil,
                basis: FoodEstimate.Basis(rawValue: basis) ?? .plate,
                servingGrams: servingGrams > 0 ? servingGrams : nil
            )
        }
    }

}
#endif
