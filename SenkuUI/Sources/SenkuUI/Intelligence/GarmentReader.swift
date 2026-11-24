#if !os(watchOS)
import CoreGraphics
import Foundation
import ImageIO
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What a photograph of one piece of clothing says about it.
///
/// Plain values, so the screen and any later wardrobe can use a reading
/// without a model, or an iOS 27 device, in sight.
struct GarmentReading: Equatable, Sendable {
    var name: String
    var type: String
    var category: String
    var colours: [String]
    var pattern: String
    var material: String
    var fit: String
    var sleeves: String
    var neckline: String
    var length: String
    var style: String
    var occasions: [String]
    var seasons: [String]
    var details: [String]
    var summary: String

    /// "Not visible" and blanks are the model saying it could not tell, and
    /// are left off the screen rather than shown as answers.
    static func shown(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let unknown = ["not visible", "unknown", "n/a", "none", "not applicable"]
        return unknown.contains(trimmed.lowercased()) ? nil : trimmed
    }

    static func shown(_ values: [String]) -> [String] {
        values.compactMap { shown($0) }
    }
}

#if canImport(FoundationModels)
/// Reads a garment off a photograph, on the device, with Apple Intelligence.
///
/// The same on-device model the food photos use, so the picture never leaves
/// the phone. Clothing is harmless to describe, but the permissive guardrail is
/// used for the same reason as food: the default one has refused ordinary
/// images for being about a body, and a refusal here would only ever be wrong.
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
enum GarmentReader {
    enum Failure: Error, Equatable {
        /// Apple Intelligence off, an unsupported device, or the model still
        /// downloading.
        case modelUnavailable
        /// It answered, but not about a piece of clothing.
        case notClothing
    }

    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    static let instructions = """
        You describe one piece of clothing, footwear or accessory in a photograph, \
        for somebody cataloguing their wardrobe. Describe only what can be seen. \
        Clothing from every tradition counts: Indian and South Asian wear (kurta, kurti, \
        sherwani, Nehru jacket, saree, lehenga, salwar, dhoti, dupatta) as well as Western wear. \
        A long tunic with a short button placket and a band collar is a kurta, not a shirt. \
        Name colours the way a shop would ("royal blue", "indigo", "olive", "off-white"), \
        the main one first, and give every colour of a pattern. \
        Name patterns precisely: ikat, block print, paisley, bandhani, geometric, diamond, \
        floral, striped, checked, plaid, polka dot, solid. Checked means a grid of squares only. \
        Name collars precisely: mandarin or band collar, button-down collar, spread collar, \
        crew neck, V-neck, round neck. \
        Give the material as the likeliest fabric from its look and say "not visible" for \
        anything the photo does not show. Lighting can tint colours: allow for warm or dim light. \
        If a person is wearing several garments, describe the one most in view. \
        If there is no clothing at all, leave the type empty.
        """

    static func read(
        _ image: CGImage,
        orientation: CGImagePropertyOrientation? = nil,
        prompt: String = ""
    ) async throws -> GarmentReading {
        guard isAvailable else { throw Failure.modelUnavailable }

        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(model: model, instructions: instructions)
        let response = try await session.respond(generating: GeneratedGarment.self) {
            Attachment(image, orientation: orientation).label("garment")
            "Describe this garment."
            let asked = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !asked.isEmpty {
                "The owner adds: \(asked)"
            }
        }

        let reading = response.content.reading
        guard GarmentReading.shown(reading.type) != nil else { throw Failure.notClothing }
        return reading
    }
}

/// The shape the model answers in.
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
@Generable(description: "One garment, footwear or accessory as seen in a photograph.")
struct GeneratedGarment {
    @Guide(description: "A short name for it, as somebody would say it: \"Navy linen shirt\".")
    var name: String

    @Guide(description: "What it is: shirt, T-shirt, kurta, jeans, dress, saree, blazer, sneakers… Empty if there is no clothing.")
    var type: String

    @Guide(
        description: "Where it goes on the body.",
        .anyOf(["top", "bottom", "dress", "outerwear", "footwear", "accessory", "other"])
    )
    var category: String

    @Guide(description: "Every colour in it, main one first — a pattern's colours too.", .count(1 ... 4))
    var colours: [String]

    @Guide(description: "The pattern, named precisely: ikat, block print, paisley, geometric, diamond, floral, striped, checked, plaid, graphic, or solid.")
    var pattern: String

    @Guide(description: "The likeliest fabric from its look, or \"not visible\".")
    var material: String

    @Guide(description: "Slim, regular, relaxed, oversized… or \"not visible\".")
    var fit: String

    @Guide(description: "Sleeve length for tops and dresses — sleeveless, short, three-quarter, long — or \"not applicable\".")
    var sleeves: String

    @Guide(description: "Neckline or collar — mandarin collar, band collar, button-down collar, spread collar, crew neck, V-neck — or \"not applicable\".")
    var neckline: String

    @Guide(description: "Where it ends on the body — cropped, waist, hip, mid-thigh, knee, midi, ankle, floor — or \"not applicable\".")
    var length: String

    @Guide(description: "Its style in a word or two: casual, smart casual, formal, ethnic, festive, sporty, streetwear…")
    var style: String

    @Guide(description: "Occasions it suits: everyday, work, party, festival, wedding, puja, beach, gym…", .count(1 ... 5))
    var occasions: [String]

    @Guide(description: "Seasons it suits: spring, summer, autumn, winter.", .count(1 ... 4))
    var seasons: [String]

    @Guide(description: "Notable details: buttons, pockets, zip, logo, embroidery, distressing… Empty if none.", .count(0 ... 5))
    var details: [String]

    @Guide(description: "One sentence describing it, answering anything the owner asked.")
    var summary: String
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension GeneratedGarment {
    var reading: GarmentReading {
        GarmentReading(
            name: name, type: type, category: category, colours: colours, pattern: pattern,
            material: material, fit: fit, sleeves: sleeves, neckline: neckline, length: length,
            style: style, occasions: occasions, seasons: seasons, details: details, summary: summary
        )
    }
}
#endif
#endif
