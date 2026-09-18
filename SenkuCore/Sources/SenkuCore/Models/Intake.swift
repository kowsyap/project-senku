import Foundation

/// A meal, a shake, or a bare figure you remembered to type.
///
/// ## Why the macros and not the food
///
/// There is no food database here, and that is a decision rather than a gap:
/// licensing one is a contract and a subscription, and scraping one is somebody
/// else's data with your training log built on top of it. What this stores is
/// what you can actually know — the grams — and the name is a label for your own
/// benefit rather than a key into anything.
public struct IntakeEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var date: Date
    /// Optional on purpose: "+40 g protein" at eleven at night is a real entry,
    /// and making somebody name it is how it does not get logged at all.
    public var name: String?
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var fiberG: Double?

    /// A calorie figure off a packet, where it disagrees with the macros.
    ///
    /// Never reconciled: 4/4/9 is an approximation — fibre yields less, alcohol
    /// is not counted at all, and food labels round every figure they print —
    /// so where both exist the app shows both and says which is which rather
    /// than averaging two numbers into one that is neither.
    public var enteredCalories: Double?

    public init(
        id: UUID = UUID(),
        date: Date = .now,
        name: String? = nil,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        fiberG: Double? = nil,
        enteredCalories: Double? = nil
    ) throws {
        for grams in [proteinG, carbsG, fatG, fiberG ?? 0] {
            guard grams >= 0, grams <= 1000 else { throw ValidationError.macroOutOfRange(grams) }
        }

        self.id = id
        self.date = date
        self.name = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilWhenEmpty
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.enteredCalories = enteredCalories
    }

    /// Calories from the macros, by the Atwater factors.
    public var derivedCalories: Double {
        proteinG * CaloriesPerGram.protein
            + carbsG * CaloriesPerGram.carbohydrate
            + fatG * CaloriesPerGram.fat
    }

    /// What this entry counts as, for the day's total: the figure you typed if
    /// you typed one, because a label knows about the olive oil and the
    /// arithmetic does not.
    public var calories: Double { enteredCalories ?? derivedCalories }

    /// Whether the two disagree by enough to be worth showing side by side.
    /// Below this it is rounding, and two numbers where one would do.
    public var hasCalorieDisagreement: Bool {
        guard let enteredCalories else { return false }
        return abs(enteredCalories - derivedCalories) > max(20, derivedCalories * 0.1)
    }

    public var isEmpty: Bool {
        proteinG == 0 && carbsG == 0 && fatG == 0 && (fiberG ?? 0) == 0 && enteredCalories == nil
    }
}

/// Something you eat often enough that typing it again is an insult.
public struct FoodFavourite: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var fiberG: Double?
    /// A calorie figure for something whose macros you do not know.
    ///
    /// The takeaway you order every fortnight is 900 kcal and an unknown split.
    /// Without this it could not be a button at all — and a button that made you
    /// guess at its protein would put a fiction into the figure this whole
    /// screen exists to keep honest.
    public var enteredCalories: Double?
    /// How often it has been logged. Ordering by this rather than by when it
    /// was added puts the four things you actually eat at the top on their own,
    /// with no sorting screen to visit.
    public var timesUsed: Int

    public init(
        id: UUID = UUID(),
        name: String,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        fiberG: Double? = nil,
        enteredCalories: Double? = nil,
        timesUsed: Int = 0
    ) {
        self.id = id
        self.name = name
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.enteredCalories = enteredCalories
        self.timesUsed = timesUsed
    }

    public var calories: Double {
        enteredCalories ?? (
            proteinG * CaloriesPerGram.protein
                + carbsG * CaloriesPerGram.carbohydrate
                + fatG * CaloriesPerGram.fat
        )
    }

    /// Nothing but a calorie figure — drawn and described differently, because
    /// it contributes to one ring and not the other.
    public var isCaloriesOnly: Bool {
        enteredCalories != nil && proteinG == 0 && carbsG == 0 && fatG == 0
    }

    /// What a new install starts with.
    ///
    /// Three things that are the same everywhere, need no weighing, and are
    /// eaten by the piece rather than by the gram — which is what makes them
    /// safe to ship as figures. Anything cooked varies too much between two
    /// kitchens to put a number on somebody else's behalf.
    ///
    /// Sizes are the usual ones: a medium banana, a medium apple, a large egg.
    /// Macros rather than calorie figures, so the protein ring gets the egg's
    /// six grams instead of nothing.
    public static let defaults: [FoodFavourite] = [
        FoodFavourite(name: "Banana", proteinG: 1.3, carbsG: 27, fatG: 0.4, fiberG: 3.1),
        FoodFavourite(name: "Apple", proteinG: 0.5, carbsG: 25, fatG: 0.3, fiberG: 4.4),
        FoodFavourite(name: "Egg", proteinG: 6.3, carbsG: 0.4, fatG: 4.8),
    ]

    /// A fresh entry, as of now.
    public func entry(at date: Date = .now) -> IntakeEntry? {
        try? IntakeEntry(
            date: date,
            name: name,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            fiberG: fiberG,
            enteredCalories: enteredCalories
        )
    }
}

/// One day's eating, against that day's targets.
public struct IntakeDay: Hashable, Sendable, Identifiable {
    public let date: Date
    public let entries: [IntakeEntry]
    public let targets: MacroTargets

    public var id: Date { date }

    public init(date: Date, entries: [IntakeEntry], targets: MacroTargets) {
        self.date = date
        self.entries = entries.sorted { $0.date > $1.date }
        self.targets = targets
    }

    public var proteinG: Double { entries.reduce(0) { $0 + $1.proteinG } }
    public var carbsG: Double { entries.reduce(0) { $0 + $1.carbsG } }
    public var fatG: Double { entries.reduce(0) { $0 + $1.fatG } }
    public var fiberG: Double { entries.reduce(0) { $0 + ($1.fiberG ?? 0) } }
    public var calories: Double { entries.reduce(0) { $0 + $1.calories } }

    /// Nothing logged is not the same as zero eaten.
    ///
    /// A day you forgot to open the app is a day with no information in it, and
    /// reporting it as "0 g — you failed" is the app lying about what it knows.
    /// Every streak and every advisory tests this first.
    public var isUnlogged: Bool { entries.isEmpty }

    public var proteinRemainingG: Double { max(0, targets.proteinGrams - proteinG) }
    public var caloriesRemaining: Double { max(0, targets.calories - calories) }

    /// Capped at one for drawing; the overage is reported separately.
    public func fraction(of value: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(1, value / target)
    }

    public var proteinFraction: Double { fraction(of: proteinG, target: targets.proteinGrams) }
    public var carbsFraction: Double { fraction(of: carbsG, target: targets.carbGrams) }
    public var fatFraction: Double { fraction(of: fatG, target: targets.fatGrams) }
    public var calorieFraction: Double { fraction(of: calories, target: targets.calories) }

    /// Protein is a floor. More than the target is not a failure — it is the
    /// macro the app pushes hardest on a cut, and nobody has ever been harmed
    /// by an extra chicken breast.
    public var isProteinMet: Bool {
        targets.proteinGrams > 0 && proteinG >= targets.proteinGrams
    }

    /// Calories are a band, not a ceiling.
    ///
    /// ## Why a band
    ///
    /// Protein can be beaten; calories cannot. Eating 900 under target is not a
    /// better day than eating 100 under — on a cut it is the day that costs you
    /// the muscle the protein was protecting, and on a bulk it is the day the
    /// bulk did not happen. Both edges have to count as a miss, which means the
    /// test is "close to the number" rather than "under it".
    ///
    /// Ten per cent either side: about 250 kcal on a 2,500 target, which is
    /// roughly the error in eyeballing a portion of rice. Tighter than that and
    /// the streak measures your kitchen scales rather than your eating.
    public static let calorieTolerance = 0.1

    public var isCaloriesMet: Bool {
        guard targets.calories > 0, !isUnlogged else { return false }
        return abs(calories - targets.calories) <= targets.calories * Self.calorieTolerance
    }

    /// Past the top of the band — the state a filling bar cannot show, since a
    /// full bar reads as success however far past full you went.
    public var isOverCalories: Bool {
        targets.calories > 0 && calories > targets.calories * (1 + Self.calorieTolerance)
    }

    /// The sentence the rings cannot say.
    public var spoken: String {
        guard !isUnlogged else { return "Nothing logged" }
        return "\(Int(proteinG.rounded())) of \(Int(targets.proteinGrams.rounded())) g protein"
            + " · \(Int(calories.rounded()).formatted()) of \(Int(targets.calories.rounded()).formatted()) kcal"
    }
}

/// Everything eaten, grouped into days.
public struct IntakeLog: Sendable {
    public let entries: [IntakeEntry]
    private let calendar: Calendar

    public init(_ entries: [IntakeEntry], calendar: Calendar = .current) {
        self.entries = entries
        self.calendar = calendar
    }

    public func entries(on date: Date) -> [IntakeEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    public func day(_ date: Date, targets: MacroTargets) -> IntakeDay {
        IntakeDay(date: date, entries: entries(on: date), targets: targets)
    }

    /// The last `days` days, newest first, days with nothing in them included —
    /// a gap in a record of eating is information.
    public func recentDays(
        _ days: Int,
        endingOn date: Date = .now,
        targets: MacroTargets
    ) -> [IntakeDay] {
        (0 ..< days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            return self.day(calendar.startOfDay(for: day), targets: targets)
        }
    }

    /// Mean calories a day across days that were actually logged.
    ///
    /// The input `AdaptiveMaintenance` has been waiting for. Unlogged days are
    /// left out rather than counted as zero, which would drag the mean down and
    /// hand the maintenance estimate a figure you never ate — and the count
    /// comes back with it so the caller can refuse to draw a conclusion from
    /// three days out of fourteen.
    public func averageCalories(
        days: Int,
        endingOn date: Date = .now
    ) -> (calories: Double, loggedDays: Int)? {
        let window: [Double] = (0 ..< days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            let entries = entries(on: day)
            guard !entries.isEmpty else { return nil }
            return entries.reduce(0) { $0 + $1.calories }
        }

        guard !window.isEmpty else { return nil }
        return (window.reduce(0, +) / Double(window.count), window.count)
    }
}

extension String {
    var nilWhenEmpty: String? { isEmpty ? nil : self }
}
