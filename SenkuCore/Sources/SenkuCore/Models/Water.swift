import Foundation

/// A drink, as logged.
public struct WaterEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var date: Date
    public var millilitres: Double
    /// Which container it came from, when it came from one. Kept so a renamed
    /// or resized bottle does not rewrite what you drank last Tuesday — the
    /// amount is stored, the container is only a note of where it came from.
    public var containerID: UUID?

    public init(
        id: UUID = UUID(),
        date: Date = .now,
        millilitres: Double,
        containerID: UUID? = nil
    ) throws {
        guard millilitres > 0, millilitres <= 5000 else {
            throw ValidationError.waterOutOfRange(millilitres)
        }
        self.id = id
        self.date = date
        self.millilitres = millilitres
        self.containerID = containerID
    }
}

/// A glass, a bottle, a flask — whatever you actually drink out of.
public struct WaterContainer: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var millilitres: Double

    public init(id: UUID = UUID(), name: String, millilitres: Double) {
        self.id = id
        self.name = name
        self.millilitres = max(1, millilitres)
    }

    /// What a new install starts with. Editable, and sized to the things most
    /// people are actually holding rather than to round numbers.
    public static let defaults: [WaterContainer] = [
        WaterContainer(name: "Glass", millilitres: 250),
        WaterContainer(name: "Bottle", millilitres: 500),
        WaterContainer(name: "Jug", millilitres: 750),
    ]
}

/// How much to drink today, and where that figure came from.
///
/// Said out loud rather than presented as one number, because the parts are
/// arguable and the total is not obviously right: someone who sees 3,450 ml
/// and no explanation concludes the app is wrong, while someone who sees
/// "2,450 base, +500 training, +500 creatine" can disagree with a part of it.
public struct WaterGoal: Hashable, Sendable {
    public var baseML: Double
    public var trainingBonusML: Double
    public var creatineBonusML: Double
    public var overrideML: Double?

    /// Creatine draws water into muscle, and the usual advice alongside it is to
    /// drink more. Half a litre is the common figure and the same size as the
    /// training-day bump, which keeps the arithmetic legible.
    public static let creatineExtraML: Double = 500

    public init(
        baseML: Double,
        trainingBonusML: Double = 0,
        creatineBonusML: Double = 0,
        overrideML: Double? = nil
    ) {
        self.baseML = baseML
        self.trainingBonusML = trainingBonusML
        self.creatineBonusML = creatineBonusML
        self.overrideML = overrideML
    }

    public var totalML: Double {
        overrideML ?? (baseML + trainingBonusML + creatineBonusML)
    }

    public var isOverridden: Bool { overrideML != nil }

    /// "2,450 + 500 training + 500 creatine", or "Your own target" when set by
    /// hand. Shown under the figure so it is never a number from nowhere.
    public var explanation: String {
        if isOverridden { return "Your own target" }

        var parts = ["\(Int(baseML)) base"]
        if trainingBonusML > 0 { parts.append("+\(Int(trainingBonusML)) training") }
        if creatineBonusML > 0 { parts.append("+\(Int(creatineBonusML)) creatine") }
        return parts.joined(separator: " ")
    }
}

/// One day's drinking, against the day's goal.
public struct WaterDay: Hashable, Sendable, Identifiable {
    public let date: Date
    public let entries: [WaterEntry]
    public let goal: WaterGoal

    public var id: Date { date }

    public init(date: Date, entries: [WaterEntry], goal: WaterGoal) {
        self.date = date
        self.entries = entries.sorted { $0.date > $1.date }
        self.goal = goal
    }

    public var totalML: Double { entries.reduce(0) { $0 + $1.millilitres } }

    /// Capped at one, so a bottle drawn from this cannot overflow its own
    /// outline. The overage is reported separately rather than lost.
    public var fraction: Double {
        guard goal.totalML > 0 else { return 0 }
        return min(1, totalML / goal.totalML)
    }

    public var percentage: Int { Int((fraction * 100).rounded()) }

    public var isMet: Bool { totalML >= goal.totalML && goal.totalML > 0 }

    public var remainingML: Double { max(0, goal.totalML - totalML) }
    public var overML: Double { max(0, totalML - goal.totalML) }

    /// The figure a shape cannot convey: "1,450 of 2,450 ml · 59%".
    ///
    /// Required, not optional. A bottle filling up is unreadable to VoiceOver
    /// and approximate to everyone else, and this is the sentence that makes
    /// the picture accountable.
    public var spoken: String {
        "\(written) · \(percentage)%"
    }

    /// The same sentence without the percentage, for where the bottle is
    /// already showing it. Printing it twice a thumb's width apart is the app
    /// filling space rather than saying anything.
    public var written: String {
        let total = Int(totalML.rounded())
        let goalML = Int(goal.totalML.rounded())
        return "\(total.formatted()) of \(goalML.formatted()) ml"
    }
}

/// Everything logged, grouped into days.
public struct WaterLog: Sendable {
    public let entries: [WaterEntry]
    private let calendar: Calendar

    public init(_ entries: [WaterEntry], calendar: Calendar = .current) {
        self.entries = entries
        self.calendar = calendar
    }

    public func entries(on date: Date) -> [WaterEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    public func totalML(on date: Date) -> Double {
        entries(on: date).reduce(0) { $0 + $1.millilitres }
    }

    /// The last `days` days, newest first, including days with nothing in them
    /// — a gap in a chart of drinking is information, not an absence of it.
    public func recentTotals(days: Int, endingOn date: Date = .now) -> [(date: Date, totalML: Double)] {
        (0 ..< days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            return (date: calendar.startOfDay(for: day), totalML: totalML(on: day))
        }
    }
}
