#if os(iOS)
import CoreGraphics
import Foundation
import ImageIO
import UIKit

/// Reads food through Google's Gemini, when you have asked it to.
///
/// ## What this costs you, beyond money
///
/// Everywhere else in this app the answer to "where does my data go" is
/// nowhere. This is the exception, and it is opt-in for that reason: the
/// photograph leaves the phone. On Gemini's paid tier Google does not train on
/// it; on the free tier they may, and a human rater may look at it. The
/// settings screen says so, and ``FoodPhotoSheet`` stops claiming the picture
/// stays local the moment this is switched on.
///
/// ## Why it exists at all
///
/// The on-device model is small, and the one job it is genuinely weak at is
/// looking at a plate of food and judging what is on it. Packets do not need
/// this — Vision reads those exactly and for free — so if you only ever
/// photograph labels, leave it off.
enum GeminiFoodReader {
    /// Flash rather than Pro: Pro left the free tier in April 2026, and for
    /// reading a panel or naming a plate the difference does not show.
    ///
    /// 2.5 rather than 3.8 because 3.8 answered every probe with "experiencing
    /// high demand" while 2.5 answered on the first attempt. `flash-latest`
    /// is not a way out — it aliases to 3.8 and inherits the same queue.
    static let model = "gemini-2.5-flash"

    private static let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!

    // MARK: - Reading

    /// A panel, from the words Vision already read. The photograph does not
    /// leave the phone in this case — only the text does.
    static func readPanel(_ lines: [String], note: String = "") async throws -> FoodEstimate {
        var parts: [Part] = [.text("Lines read off the panel:\n" + lines.joined(separator: "\n"))]
        if !note.isEmpty { parts.append(.text(FoodPrompts.note(note))) }
        return try await send(system: FoodPrompts.panel, parts: parts)
    }

    /// A plate. This one does send the photograph.
    static func readPlate(
        _ image: CGImage,
        orientation: CGImagePropertyOrientation?,
        note: String = ""
    ) async throws -> FoodEstimate {
        guard let jpeg = jpeg(from: image, orientation: orientation) else {
            throw GeminiFailure.malformedResponse
        }
        var parts: [Part] = [
            .text("What is in this photograph, and what are its macros?"),
            .image(jpeg),
        ]
        if !note.isEmpty { parts.append(.text(FoodPrompts.note(note))) }
        return try await send(system: FoodPrompts.plate, parts: parts)
    }

    // MARK: - The call

    private enum Part {
        case text(String)
        case image(Data)
    }

    private static func send(system: String, parts: [Part]) async throws -> FoodEstimate {
        guard let key = GeminiAccount.key else { throw GeminiFailure.noKey }

        let input: [[String: Any]] = parts.map { part in
            switch part {
            case .text(let text):
                return ["type": "text", "text": text]
            case .image(let data):
                return [
                    "type": "image",
                    "mime_type": "image/jpeg",
                    "data": data.base64EncodedString(),
                ]
            }
        }

        let body: [String: Any] = [
            "model": model,
            "system_instruction": system,
            "input": input,
            // The bare schema, not wrapped in a type/mime_type envelope.
            // Wrapped, the field is accepted and silently ignored — the reply
            // comes back as cheerful markdown prose and parsing fails a step
            // later, pointing at the wrong thing.
            "response_format": schema,
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        var data = Data()
        var response: URLResponse?

        // Retried because "experiencing high demand" is what this endpoint
        // says most of the time on a free key, and it clears within seconds.
        // Three tries rather than one turns the common case from a failure
        // into a pause.
        for attempt in 0 ..< 3 {
            (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 503 else { break }
            Trace.food("gemini: 503, attempt \(attempt + 1) of 3")
            guard attempt < 2 else { throw GeminiFailure.busy }
            try await Task.sleep(for: .seconds(1 << attempt))
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            // The body, not just the code. Google explains itself properly —
            // "API key not valid", "Unknown name 'input'" — and throwing that
            // away leaves every wire-format mistake looking like a bad
            // photograph, which is the hole that cost an afternoon already.
            let said = String(data: data, encoding: .utf8) ?? "<no body>"
            Trace.food("gemini: HTTP \(http.statusCode) — \(said.prefix(600))")

            switch http.statusCode {
            // A rejected key comes back 400 with API_KEY_INVALID, not 401 —
            // checked against the live endpoint rather than assumed.
            case 400 where said.contains("API_KEY_INVALID"): throw GeminiFailure.unauthorized
            case 401, 403: throw GeminiFailure.unauthorized
            case 429: throw GeminiFailure.rateLimited
            case 503: throw GeminiFailure.busy
            default: throw GeminiFailure.http(http.statusCode)
            }
        }

        do {
            return try GeminiResponse.estimate(from: data)
        } catch {
            let said = String(data: data, encoding: .utf8) ?? "<no body>"
            Trace.food("gemini: 200 but unparsed — \(said.prefix(600))")
            throw error
        }
    }

    private static var schema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "proteinG": ["type": "number"],
                "carbsG": ["type": "number"],
                "fatG": ["type": "number"],
                "fiberG": ["type": "number"],
                "labelCalories": ["type": "number"],
                "basis": ["type": "string", "enum": ["plate", "per100g", "perServing"]],
                "servingGrams": ["type": "number"],
            ],
            "required": [
                "name", "proteinG", "carbsG", "fatG",
                "fiberG", "labelCalories", "basis", "servingGrams",
            ],
        ]
    }

    // MARK: - The picture

    /// A JPEG, turned upright and cut down to something worth sending.
    ///
    /// Drawing it through a renderer bakes the orientation in, so a photograph
    /// taken sideways does not arrive as a sideways plate. The long edge is
    /// capped because a 12-megapixel original buys no accuracy here and is paid
    /// for twice, in upload time and in tokens.
    private static func jpeg(
        from image: CGImage,
        orientation: CGImagePropertyOrientation?,
        longEdge: CGFloat = 1536
    ) -> Data? {
        let upright = UIImage(
            cgImage: image,
            scale: 1,
            orientation: orientation.map(UIImage.Orientation.init) ?? .up
        )

        let size = upright.size
        let scale = min(1, longEdge / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format)
            .image { _ in upright.draw(in: CGRect(origin: .zero, size: target)) }
            .jpegData(compressionQuality: 0.8)
    }
}

extension UIImage.Orientation {
    /// The inverse of the mapping in ``FoodPhotoSheet``, so a photograph makes
    /// the round trip from camera to Core Graphics and back without turning.
    init(_ orientation: CGImagePropertyOrientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
#endif
