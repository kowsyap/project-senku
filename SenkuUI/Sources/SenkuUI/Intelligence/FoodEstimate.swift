#if !os(watchOS)
import Foundation
import SenkuCore

/// What a photo was read as, before anybody agreed to it.
///
/// ## Why this is not an `IntakeEntry`
///
/// An entry is something you have said happened. This is a guess, and keeping
/// the two types apart is what stops the guess being written to the log by a
/// code path that forgot to ask. Nothing here reaches `IntakeStore` — it fills
/// in ``IntakeEditor`` and waits to be accepted, changed, or thrown away.
///
/// ## Why a photo cannot know the grams
///
/// The model can tell chicken from salmon. It cannot tell 120 g of it from
/// 180 g, because that information is not in the picture — no model fixes
/// that, and a confident number here would be exactly the fiction the food
/// screen exists to avoid. So the figures arrive as a draft to correct rather
/// than an answer to accept.
struct FoodEstimate: Equatable, Sendable {
    /// What the model thinks it is looking at. Becomes the entry's name, so it
    /// is a label for you rather than a key into anything — see ``IntakeEntry``.
    var name: String
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double?
    /// Only when the model read a figure off a label in the shot. A calorie
    /// count it derived from its own macros is not a packet figure, and
    /// pretending otherwise would put it on the wrong side of the distinction
    /// ``IntakeEntry/enteredCalories`` exists to keep.
    var calories: Double?

    /// What the figures above are figures *of*.
    ///
    /// The distinction the first version of this missed entirely. A plate is a
    /// guess at what is in front of you and can go straight into the log. A
    /// label is an exact statement about 100 g of a product, or about one
    /// serving of it, and it is not an entry until somebody says how much they
    /// had. Logging a per-100 g column as a meal is how you record a biscuit as
    /// dinner.
    var basis: Basis = .plate

    /// Where the figures came from, which `basis` no longer tells you.
    ///
    /// Both a packet and a plate now report per-serving figures so that both
    /// can be counted in servings. That makes `basis` a statement about the
    /// arithmetic and nothing else — and the one thing left worth saying on
    /// screen is whether these numbers were read or guessed, which is this.
    var source: Source = .plate

    enum Source: Equatable, Sendable {
        /// Transcribed off a nutrition panel. Exact.
        case panel
        /// Estimated from a photograph of food. Not exact, and said so.
        case plate
    }

    /// Grams in one serving, where the label said so — "per serving (30 g)".
    /// Lets the scaling step offer servings as well as grams.
    var servingGrams: Double?

    enum Basis: String, Equatable, Sendable, CaseIterable {
        /// Food as photographed. An estimate, and presented as one.
        case plate
        /// A label column headed per 100 g.
        case per100g
        /// A label column headed per serving.
        case perServing

        /// Whether the figures need a quantity before they mean anything.
        var needsQuantity: Bool { self != .plate }
    }

    /// The reading multiplied out to a number of servings.
    ///
    /// The path for a per-serving column, which is most labels: the packet
    /// already states what one of them contains, so two of them is arithmetic
    /// rather than estimation. Matches how the quick-add row counts servings,
    /// because it is the same question being asked about the same thing.
    func scaled(servings: Int) -> FoodEstimate {
        let count = Double(max(1, servings))

        var scaled = self
        scaled.proteinG = proteinG * count
        scaled.carbsG = carbsG * count
        scaled.fatG = fatG * count
        scaled.fiberG = fiberG.map { $0 * count }
        scaled.calories = calories.map { $0 * count }
        scaled.basis = .plate
        scaled.servingGrams = nil
        return scaled
    }

    /// The same reading scaled to the amount actually eaten.
    ///
    /// Only meaningful for a label. `grams` is what went in you; the arithmetic
    /// is the label's own, which is the entire reason a photographed label
    /// beats a photographed plate — nothing here is estimated.
    func scaled(toGrams grams: Double) -> FoodEstimate {
        let per100 = basis == .per100g
        let base = per100 ? 100 : (servingGrams ?? 100)
        guard base > 0 else { return self }
        let factor = grams / base

        var scaled = self
        scaled.proteinG = proteinG * factor
        scaled.carbsG = carbsG * factor
        scaled.fatG = fatG * factor
        scaled.fiberG = fiberG.map { $0 * factor }
        scaled.calories = calories.map { $0 * factor }
        scaled.basis = .plate
        scaled.servingGrams = nil
        return scaled
    }

    /// The range a macro has to land in to be believable.
    ///
    /// The same bound `IntakeEntry` enforces. Repeated rather than imported
    /// because the check here answers a different question: not "is this
    /// storable" but "did the model return something worth showing anyone".
    static let plausible: ClosedRange<Double> = 0 ... 1000

    /// The draft entry, or nil when the model returned something that cannot be
    /// true.
    ///
    /// Out-of-range figures are refused whole rather than clamped. Clamping
    /// 1400 g of protein to 1000 g would hand you a number that is still wrong
    /// but no longer obviously wrong, and the one thing worse than a failed
    /// estimate is a plausible-looking bad one.
    func proposal() -> IntakeEntry? {
        let macros = [proteinG, carbsG, fatG, fiberG].compactMap { $0 }
        guard macros.allSatisfy(Self.plausible.contains) else { return nil }
        if let calories, !(0 ... 5000).contains(calories) { return nil }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return try? IntakeEntry(
            name: trimmed.isEmpty ? nil : trimmed,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            enteredCalories: calories
        )
    }

    /// One line for the log.
    ///
    /// Assembled in pieces rather than one interpolated literal: the whole
    /// thing in a single string defeated the type checker outright, and a
    /// diagnostic-free compile error is a worse debugging session than the one
    /// this line exists to prevent.
    var traceLine: String {
        func figure(_ value: Double?) -> String {
            guard let value else { return "-" }
            return String(value)
        }

        var parts: [String] = ["read:"]
        parts.append("name=" + (name.isEmpty ? "-" : name))
        parts.append("basis=" + basis.rawValue)
        parts.append("p=" + String(proteinG))
        parts.append("c=" + String(carbsG))
        parts.append("f=" + String(fatG))
        parts.append("fib=" + figure(fiberG))
        parts.append("kcal=" + figure(calories))
        parts.append("serving=" + figure(servingGrams))
        return parts.joined(separator: " ")
    }

    /// Whether there is anything in here worth opening an editor for.
    ///
    /// A photo of a table, or of something the model could not place, comes
    /// back as zeroes. Better to say so than to present an empty form as
    /// though it were a reading.
    var isEmpty: Bool {
        proteinG <= 0 && carbsG <= 0 && fatG <= 0 && (calories ?? 0) <= 0
    }
}
#endif
