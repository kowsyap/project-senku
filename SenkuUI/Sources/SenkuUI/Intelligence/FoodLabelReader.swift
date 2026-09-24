#if !os(watchOS)
import CoreGraphics
import Foundation
import ImageIO

#if canImport(Vision)
import Vision
#endif

#if canImport(Vision)

/// Gets the words off a packet before anything tries to understand them.
///
/// ## Why not just show the model the photograph
///
/// That was the first version, and a tin of tuna disproved it: asked to read a
/// Nutrition Facts panel wrapped around a can, the model returned the one
/// figure printed large — 150 kcal — and invented the rest, including a fat
/// figure of 0.6 g against a printed 7 g. It was not misreading lines, it was
/// not resolving them at all.
///
/// Vision's text recogniser is built for exactly this: small type, low
/// contrast, curved surfaces, rotated words. So the labour is split — Vision
/// reads the characters, and the language model does the part it is actually
/// good at, which is working out that "Total Fat 7g" is the fat and "Sat. Fat
/// 1g" underneath it is not.
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
enum FoodLabelReader {
    /// Every line of text found, top to bottom as Vision returns them.
    static func transcript(
        of image: CGImage,
        orientation: CGImagePropertyOrientation? = nil
    ) async -> [String] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Off deliberately. Language correction is tuned for prose, and on a
        // panel that is mostly digits and units it is as likely to "correct"
        // 7g into something else as it is to help.
        request.usesLanguageCorrection = false
        request.customWords = [
            "Calories", "Protein", "Carbohydrate", "Carb", "Fat", "Saturated",
            "Trans", "Fiber", "Fibre", "Sugars", "Sodium", "Cholesterol",
            "Serving", "servings", "kcal", "kJ",
        ]

        guard let observations = try? await request.perform(on: image, orientation: orientation) else {
            return []
        }
        return observations.map(\.transcript).filter { !$0.isEmpty }
    }

    /// Whether the words found look like a nutrition panel rather than a plate
    /// with a logo in shot.
    ///
    /// Two matches rather than one: "fat" alone appears on the front of half
    /// the packets in a supermarket, and reading a marketing claim as a table
    /// is how you log a slogan.
    static func looksLikeAPanel(_ lines: [String]) -> Bool {
        let text = lines.joined(separator: " ").lowercased()
        let markers = [
            "nutrition", "serving size", "per serving", "calories",
            "protein", "total fat", "carbohydrate", "total carb",
        ]
        return markers.filter(text.contains).count >= 2
    }
}

#endif
#endif
