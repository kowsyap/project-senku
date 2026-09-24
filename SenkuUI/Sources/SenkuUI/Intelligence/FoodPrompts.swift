#if !os(watchOS)
import Foundation

/// What a model is told before it is shown anything.
///
/// Kept apart from any one reader because there are two of them now — the
/// on-device model and, when somebody has switched it on, Gemini — and the
/// thing that must not happen is the two drifting into reading the same packet
/// by different rules. One set of instructions, both callers.
enum FoodPrompts {
    /// What the person added about the meal, wrapped so the model knows it
    /// came from them rather than from the picture.
    ///
    /// Marked as the cook's own account because it outranks the photograph on
    /// everything a photograph cannot show — oil, butter, what is under the
    /// sauce — and is worth nothing on what it can.
    static func note(_ text: String) -> String {
        """
        The person who ate this adds: \(text)

        Take that as true. It is what they know and the photograph does not — \
        how it was cooked, what went in, what is underneath. Let it change the \
        figures where it should.
        """
    }

    /// Reading a panel that Vision has already turned into text.
    ///
    /// The line mapping is spelled out because the failure it fixes was
    /// specific: shown a tin of tuna, the model returned the saturated fat
    /// where the total fat belonged. A Nutrition Facts panel indents its
    /// sub-lines, and indentation does not survive being read into a list of
    /// strings, so the relationship has to be stated rather than seen.
    static let panel = """
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

    /// Looking at food rather than a packet.
    ///
    /// Asked for one serving and its weight, rather than "the portion shown",
    /// so that a plate arrives in the same shape a packet does and can be
    /// counted the same way. Somebody who ate two platefuls should be able to
    /// say so without arithmetic.
    static let plate = """
        You are shown a photograph of food. Report the macronutrients of ONE \
        serving of it, and how much one serving weighs.

        Treat the portion in the photograph as one serving. Put its weight in \
        grams in `servingGrams` — your best estimate of what is actually on \
        the plate, not a standard portion for that dish. Set `basis` to \
        "perServing".

        Leave the calorie figure at zero: something downstream derives it from \
        the macros, and it needs to know the number was not measured.

        Name the food plainly, as somebody would say it: "chicken biryani", \
        not "spiced rice with poultry".

        If the picture is not food, or you cannot tell what it is, return zero \
        for every macro and leave the name empty. A refusal is more useful \
        than a guess.
        """
}
#endif
