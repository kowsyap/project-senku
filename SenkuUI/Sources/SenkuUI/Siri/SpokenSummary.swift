import Foundation
import SenkuCore

/// The sentences Siri reads back.
///
/// Separate from the intents that speak them, and with no `AppIntents` import,
/// so the wording can be tested on the host — an intent can only be checked by
/// talking to a phone, and "what does it actually say when nothing is logged"
/// is not a question worth answering by hand every time.
///
/// ## Spoken is not written
///
/// The screen can show `96 / 166 g` and be understood at a glance. Said aloud
/// that is "ninety six slash one hundred and sixty six gee", so these read as
/// sentences: units spelled out, the target kept in, and the figure that
/// actually answers the question first.
public enum SpokenSummary {

    // MARK: - Weight

    /// What the scales say, and what the trend makes of it.
    ///
    /// The trend rather than the last reading is the honest answer to "how am I
    /// doing" — one morning is mostly water — but the last reading is the
    /// honest answer to "what do I weigh", so both are here and each is
    /// labelled.
    public static func weight(_ series: WeightSeries, in system: UnitSystem) -> String {
        guard let latest = series.latest else {
            return "Nothing weighed in yet."
        }

        var sentence = Display.mass(latest.weightKG, in: system)

        if let rate = series.weeklyChangeKG, abs(rate) >= 0.05 {
            let direction = rate < 0 ? "down" : "up"
            sentence += ", \(direction) \(Display.mass(abs(rate), in: system)) a week on the trend"
        } else if series.weeklyChangeKG != nil {
            sentence += ", holding steady"
        }

        return sentence + "."
    }

    // MARK: - Water

    public static func water(_ day: WaterDay) -> String {
        let total = Int(day.totalML.rounded()).formatted()
        let goal = Int(day.goal.totalML.rounded()).formatted()

        guard day.totalML > 0 else {
            return "No water logged yet today. Your goal is \(goal) millilitres."
        }

        if day.isMet {
            let over = Int(day.overML.rounded())
            return over > 0
                ? "\(total) millilitres — goal met, \(over.formatted()) over."
                : "\(total) millilitres — goal met."
        }

        let left = Int(day.remainingML.rounded()).formatted()
        return "\(total) of \(goal) millilitres, \(day.percentage) percent. \(left) to go."
    }

    // MARK: - Food

    /// Protein first, because it is the headline figure on the screen too.
    ///
    /// A day with nothing in it says so rather than reading out two zeroes —
    /// "nothing logged" and "zero grams of protein" are different claims, and
    /// only the first one is true before breakfast.
    public static func intake(_ day: IntakeDay) -> String {
        guard !day.isUnlogged else {
            return "Nothing logged today. Your target is"
                + " \(grams(day.targets.proteinGrams)) of protein"
                + " and \(calories(day.targets.calories)) calories."
        }

        var sentence = "\(grams(day.proteinG)) of \(grams(day.targets.proteinGrams)) of protein"
        sentence += ", \(calories(day.calories)) of \(calories(day.targets.calories)) calories"

        if day.isProteinMet && day.isCaloriesMet {
            sentence += ". Both targets met."
        } else if day.isOverCalories {
            sentence += ". Over on calories."
        }

        return sentence + "."
    }

    /// Protein alone, for the question that asks about it alone.
    public static func protein(_ day: IntakeDay) -> String {
        guard !day.isUnlogged else {
            return "No protein logged today. Your target is \(grams(day.targets.proteinGrams))."
        }

        let sentence = "\(grams(day.proteinG)) of \(grams(day.targets.proteinGrams))"
        guard !day.isProteinMet else { return sentence + ". Target met." }

        return sentence + ", \(grams(day.proteinRemainingG)) to go."
    }

    // MARK: - Saying numbers out loud

    /// "40 grams", not "40 g" — a voice assistant reading "g" says "gee".
    private static func grams(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return "\(rounded.formatted()) gram\(rounded == 1 ? "" : "s")"
    }

    private static func calories(_ value: Double) -> String {
        Int(value.rounded()).formatted()
    }
}
