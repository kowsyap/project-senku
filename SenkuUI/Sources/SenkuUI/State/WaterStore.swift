import Foundation
import Observation
import SenkuCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// What you drank, what you are aiming at, and whether you took creatine.
///
/// The goal is never stored. It is resolved from the profile, the day's
/// training and the creatine switch every time it is asked for, so changing
/// your weight or dropping creatine moves today's target immediately instead of
/// leaving a stale number to be noticed weeks later.
@Observable
public final class WaterStore {
    static let entriesKey = "senku.water.entries.v1"
    static let settingsKey = "senku.water.settings.v1"
    static let creatineKey = "senku.water.creatineDays.v1"

    /// What the user has chosen, as opposed to what is computed.
    public struct Settings: Codable, Hashable, Sendable {
        public var containers: [WaterContainer] = WaterContainer.defaults
        public var goalOverrideML: Double?
        /// Whether creatine is part of the routine at all. Adds to the goal and
        /// puts a daily tick on the screen; off, neither exists.
        public var takesCreatine = false
        public var remindersOn = false
        /// Every this many minutes inside the window below.
        public var reminderIntervalMinutes = 120
        public var reminderStartHour = 8
        public var reminderEndHour = 22
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    public private(set) var entries: [WaterEntry] = []
    public private(set) var settings = Settings()
    /// Days creatine was taken, as start-of-day timestamps.
    public private(set) var creatineDays: Set<Date> = []

    public init(defaults: UserDefaults = SenkuStorage.shared, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        self.entries = Self.load([WaterEntry].self, key: Self.entriesKey, from: defaults) ?? []
        self.settings = Self.load(Settings.self, key: Self.settingsKey, from: defaults) ?? Settings()
        self.creatineDays = Set(Self.load([Date].self, key: Self.creatineKey, from: defaults) ?? [])

        migrate()
    }

    /// Re-reads everything from the shared container.
    ///
    /// ## Why a store loaded once at launch is not enough
    ///
    /// The widget logs a drink in its own process, writing straight into the
    /// App Group, and nothing tells this object about it. Held in memory from
    /// launch, it would go on showing the total it read at launch — and worse,
    /// the next drink logged inside the app would write its stale array back
    /// over the widget's, so the widget's glass would vanish. A drink is a
    /// read-modify-write of one shared array from two processes, so every
    /// mutation starts by reading what is actually there, and the app refreshes
    /// whenever it comes forward.
    public func reload() {
        entries = Self.load([WaterEntry].self, key: Self.entriesKey, from: defaults) ?? []
        settings = Self.load(Settings.self, key: Self.settingsKey, from: defaults) ?? Settings()
        creatineDays = Set(Self.load([Date].self, key: Self.creatineKey, from: defaults) ?? [])
    }

    /// Brings stored settings up to what the app now allows.
    ///
    /// Two things, both from decisions taken after people had already used the
    /// screen: the third container was called "Large bottle" before there was a
    /// jug to draw it as, and a fourth could be added before the row was capped
    /// at three. A container is a button, not a record — the drinks logged
    /// through it keep their own amounts — so trimming one takes nothing with
    /// it, and leaving a fourth in storage would leave a button the settings
    /// screen has no way to remove.
    private func migrate() {
        var changed = false

        if let index = settings.containers.firstIndex(where: { $0.name == "Large bottle" }) {
            settings.containers[index].name = "Jug"
            changed = true
        }

        if settings.containers.count > Self.containerCount {
            settings.containers = Array(settings.containers.prefix(Self.containerCount))
            changed = true
        }

        while settings.containers.count < Self.containerCount {
            let missing = WaterContainer.defaults[settings.containers.count]
            settings.containers.append(missing)
            changed = true
        }

        if changed { persistSettings() }
    }

    /// Three, and the screen offers no way to change it. See the settings page
    /// for why.
    public static let containerCount = 3

    public var log: WaterLog { WaterLog(entries, calendar: calendar) }

    // MARK: - The goal

    /// Today's target, and the parts it is made of.
    ///
    /// A training day is one with a logged workout, which is why this takes the
    /// workout store: before F3 the requirements called for a manual toggle,
    /// and a toggle asking whether you trained today, on a device that knows,
    /// would have been the app making its own problem into your chore.
    public func goal(
        profile: ProfileStore.Profile?,
        workouts: WorkoutStore?,
        on date: Date = .now
    ) -> WaterGoal {
        let macros = profile?.plan.macros
        let base = macros?.waterML ?? 2000

        let trained = workouts?.history.contains { calendar.isDate($0.date, inSameDayAs: date) } ?? false

        return WaterGoal(
            baseML: base,
            trainingBonusML: trained ? (macros?.trainingDayExtraWaterML ?? 500) : 0,
            creatineBonusML: settings.takesCreatine ? WaterGoal.creatineExtraML : 0,
            overrideML: settings.goalOverrideML
        )
    }

    public func day(
        _ date: Date = .now,
        profile: ProfileStore.Profile?,
        workouts: WorkoutStore?
    ) -> WaterDay {
        WaterDay(
            date: date,
            entries: log.entries(on: date),
            goal: goal(profile: profile, workouts: workouts, on: date)
        )
    }

    // MARK: - Drinking

    @discardableResult
    public func add(millilitres: Double, container: WaterContainer? = nil, at date: Date = .now) -> Bool {
        reload()

        guard let entry = try? WaterEntry(
            date: date,
            millilitres: millilitres,
            containerID: container?.id
        ) else { return false }

        entries.append(entry)
        entries.sort { $0.date > $1.date }
        persistEntries()
        return true
    }

    public func delete(_ entry: WaterEntry) {
        reload()
        entries.removeAll { $0.id == entry.id }
        persistEntries()
    }

    /// Undo, which is the button people actually want after a mis-tap.
    public func undoLast(on date: Date = .now) {
        guard let last = log.entries(on: date).first else { return }
        delete(last)
    }

    public func restore(_ entry: WaterEntry) {
        reload()
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        entries.sort { $0.date > $1.date }
        persistEntries()
    }

    // MARK: - Creatine

    public func tookCreatine(on date: Date = .now) -> Bool {
        creatineDays.contains(calendar.startOfDay(for: date))
    }

    public func setCreatine(_ taken: Bool, on date: Date = .now) {
        let day = calendar.startOfDay(for: date)
        if taken {
            creatineDays.insert(day)
        } else {
            creatineDays.remove(day)
        }
        persistCreatine()
    }

    /// Consecutive days up to today. Creatine works by saturation rather than
    /// by any one dose, so the streak is the only figure about it worth showing.
    public var creatineStreak: Int {
        var streak = 0
        var day = calendar.startOfDay(for: .now)

        // Today not being ticked yet does not break a streak — it is only
        // mid-afternoon, and a counter that resets every morning would be
        // wrong about most of the day.
        if !creatineDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        while creatineDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: - Settings

    public func update(_ change: (inout Settings) -> Void) {
        var copy = settings
        change(&copy)
        settings = copy
        persistSettings()
    }

    // MARK: - Storage

    private func persistEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.entriesKey)
        reloadWidgets()
    }

    private func persistSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.settingsKey)
    }

    private func persistCreatine() {
        guard let data = try? JSONEncoder().encode(Array(creatineDays)) else { return }
        defaults.set(data, forKey: Self.creatineKey)
    }

    /// The widget shows today's total, so anything that changes it has to say
    /// so — a Home Screen that is quietly out of date is worse than one that
    /// shows nothing.
    private func reloadWidgets() {
        #if canImport(WidgetKit) && !os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
