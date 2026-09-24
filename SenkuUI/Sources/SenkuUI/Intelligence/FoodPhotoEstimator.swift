#if !os(watchOS)
import CoreGraphics
import Foundation
import ImageIO
import SenkuCore

#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)

/// Reads a plate off a photograph, on the device.
///
/// ## Why on-device, and why that is the whole point
///
/// Photographing what you eat and posting it to somebody's server is the
/// version of this feature that already exists everywhere, and it is the one
/// the rest of this app is arranged against: no cloud, no account, nothing
/// about your body leaving the phone. Apple's model runs locally, so the photo
/// is read and forgotten on the device and none of that has to be qualified.
///
/// ## Why iOS 27
///
/// The on-device model only learned to accept images in iOS 27. Before that
/// this could not be built the honest way at all, which is why the button does
/// not exist on older systems rather than falling back to a service.
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
enum FoodPhotoEstimator {
    enum Failure: Error, Equatable {
        /// The model is not there: an unsupported device, or assets still
        /// downloading. Distinct from a bad reading, because the answer for you
        /// is different — wait or give up, rather than retake the shot.
        case modelUnavailable
        /// The model answered, but with nothing a meal could be.
        case unreadable
    }

    /// Whether the button should be on screen at all.
    ///
    /// Checked rather than assumed: iOS 27 on a device without the model is a
    /// real combination, and a button that fails when tapped is worse than a
    /// button that was never offered.
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// What the model is told before it is shown anything.
    ///
    /// The instruction to leave calories nil unless a label is legible is the
    /// load-bearing one. `IntakeEntry` keeps a packet figure and a derived
    /// figure apart on purpose, and a model that helpfully computed 4/4/9 into
    /// `enteredCalories` would collapse that distinction while looking correct.
    /// What the model is told when it is reading a panel that Vision has
    /// already turned into text.
    ///
    /// The line mapping is spelled out because the failure it fixes was
    /// specific: shown a tin of tuna, the model returned the saturated fat
    /// where the total fat belonged. A Nutrition Facts panel indents its
    /// sub-lines, and indentation does not survive being read into a list of
    /// strings, so the relationship has to be stated rather than seen.
    private static let panelInstructions = """
        You are given lines of text read off a nutrition panel by a text \
        recogniser. The lines may be out of order, and a panel printed in two \
        columns may arrive interleaved.

        Map exactly these lines and no others:

        - "Total Fat" is the fat. "Saturated Fat", "Sat. Fat" and "Trans Fat" \
          are indented underneath it and are NOT the fat figure.
        - "Total Carbohydrate" or "Total Carb." is the carbohydrate. "Dietary \
          Fiber", "Total Sugars" and "Added Sugars" are indented underneath it \
          and are NOT the carbohydrate figure.
        - "Protein" is the protein.
        - "Dietary Fiber" is the fibre.
        - "Calories" is the calorie figure.
        - "Serving size", where it gives a weight in brackets such as \
          "1/2 cup (85g)", gives `servingGrams` — the number in grams, 85, not \
          the cup measure.

        Set `basis` to "perServing" when the figures are headed \
        "Amount/serving", "per serving" or "per portion", and "per100g" when \
        they are headed per 100 g or per 100 ml.

        If a figure is not in the text, return zero for it. Do not estimate, \
        do not infer it from the product name, and do not calculate it from \
        the other figures. A zero is a blank somebody will fill in; a plausible \
        invented number is one they will not notice is wrong.

        Ignore sodium, cholesterol, vitamins and percentages entirely.

        Name the food from the product name if one appears, otherwise leave \
        the name empty.
        """

    /// What the model is told when it is looking at food rather than a packet.
    private static let plateInstructions = """
        You are shown a photograph of food. Estimate the macronutrients of the \
        portion in the picture, not of a standard serving of that dish.

        Set `basis` to "plate" and `servingGrams` to zero.

        Leave the calorie figure at zero: something downstream derives it from \
        the macros, and it needs to know the number was not measured.

        Name the food plainly, as somebody would say it: "chicken and rice", \
        not "grilled poultry with steamed grains".

        If the picture is not food, or you cannot tell what it is, return zero \
        for every macro and leave the name empty. A refusal is more useful \
        than a guess.
        """

    /// The reading, or a `Failure`.
    ///
    /// Never writes anything. What comes back is a draft for ``IntakeEditor``,
    /// and the person holding the phone is the one who decides it happened.
    static func estimate(
        _ image: CGImage,
        orientation: CGImagePropertyOrientation? = nil
    ) async throws -> FoodEstimate {
        guard isAvailable else { throw Failure.modelUnavailable }

        // Vision first, always. It costs a fraction of a second and it decides
        // which of two quite different jobs this is.
        let lines = await FoodLabelReader.transcript(of: image, orientation: orientation)
        let isPanel = FoodLabelReader.looksLikeAPanel(lines)
        Trace.food("ocr: \(lines.count) line(s), panel=\(isPanel)")
        if isPanel { Trace.food("ocr: \(lines.joined(separator: " | "))") }

        let raw: GeneratedFood
        do {
            raw = isPanel
                ? try await readPanel(lines)
                : try await readPlate(image, orientation)
        } catch {
            // The reason, not just the fact. A session can refuse for reasons
            // that have nothing to do with the photograph — a guardrail, a
            // context window, assets still unpacking — and every one of them
            // reached the screen as "could not read that one" until this line
            // existed.
            Trace.food("model failed: \(error)")
            throw error
        }

        // Logged before anything interprets it: every later number is derived
        // from these, so when one comes out wrong this is the line that says
        // whether the model misread the packet or we mishandled what it read.
        Trace.food(
            """
            read: name=\(raw.name.isEmpty ? "-" : raw.name) basis=\(raw.basis) \
            p=\(raw.proteinG) c=\(raw.carbsG) f=\(raw.fatG) fib=\(raw.fiberG) \
            kcal=\(raw.labelCalories) serving=\(raw.servingGrams)
            """
        )

        let estimate = raw.estimate
        guard !estimate.isEmpty else {
            Trace.food("read: nothing in it, refusing")
            throw Failure.unreadable
        }
        return estimate
    }

    /// The model, with the guardrail that fits the job.
    ///
    /// The default guardrail refuses this outright — "May contain unsafe
    /// content" — and it is not being stupid: a prompt asking for grams of
    /// protein looks like a request for dietary advice, which is exactly what
    /// it is meant to stop. But nothing here is advice. The input is a packet
    /// the person photographed and the output is the same figures rearranged,
    /// which is the case `permissiveContentTransformations` exists for.
    private static var model: SystemLanguageModel {
        SystemLanguageModel(guardrails: .permissiveContentTransformations)
    }

    /// The packet path: the model never sees the photograph, only the words.
    private static func readPanel(_ lines: [String]) async throws -> GeneratedFood {
        let session = LanguageModelSession(model: model, instructions: panelInstructions)
        let response = try await session.respond(generating: GeneratedFood.self) {
            "Lines read off the panel:"
            lines.joined(separator: "\n")
        }
        return response.content
    }

    /// The plate path, where there is nothing written down to read.
    private static func readPlate(
        _ image: CGImage,
        _ orientation: CGImagePropertyOrientation?
    ) async throws -> GeneratedFood {
        let session = LanguageModelSession(model: model, instructions: plateInstructions)
        let response = try await session.respond(generating: GeneratedFood.self) {
            Attachment(image, orientation: orientation).label("meal")
            "What is in this photograph, and what are its macros?"
        }
        return response.content
    }
}

/// The shape the model is made to answer in.
///
/// Separate from ``FoodEstimate`` so that everything downstream — the range
/// checks, the mapping onto an entry, the tests — is plain Swift that does not
/// need a model, or an iOS 27 device, to run.
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
@Generable(description: "Macronutrients, either transcribed from a nutrition panel or estimated from a photograph of food.")
struct GeneratedFood {
    @Guide(description: "The food, named the way somebody would say it. Empty if this is not food.")
    var name: String

    @Guide(description: "Protein in grams.", .range(0 ... 1000))
    var proteinG: Double

    @Guide(description: "Carbohydrate in grams. Not fibre, not sugars.", .range(0 ... 1000))
    var carbsG: Double

    @Guide(description: "Total fat in grams. Not saturated fat, not trans fat.", .range(0 ... 1000))
    var fatG: Double

    @Guide(description: "Fibre in grams, or zero.", .range(0 ... 1000))
    var fiberG: Double

    @Guide(description: "Calories as printed on a panel. Zero when estimating from food.", .range(0 ... 5000))
    var labelCalories: Double

    @Guide(
        description: "What the figures are of: \"per100g\" or \"perServing\" when read off a label, \"plate\" when estimated from food.",
        .anyOf(["plate", "per100g", "perServing"])
    )
    var basis: String

    @Guide(description: "Grams in one serving, from a stated serving size. Zero otherwise.", .range(0 ... 5000))
    var servingGrams: Double
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
extension GeneratedFood {
    /// Zero is how the model says "not applicable" — a `Generable` field cannot
    /// be left out — so it is translated back into absence here rather than
    /// being stored as a real reading of nothing.
    var estimate: FoodEstimate {
        FoodEstimate(
            name: name,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG > 0 ? fiberG : nil,
            calories: labelCalories > 0 ? labelCalories : nil,
            // An unrecognised string falls back to `.plate`, which is the
            // cautious end: a plate is shown as an estimate to be corrected,
            // where a wrongly-claimed label would be presented as exact.
            basis: FoodEstimate.Basis(rawValue: basis) ?? .plate,
            servingGrams: servingGrams > 0 ? servingGrams : nil
        )
    }
}

#endif
#endif
