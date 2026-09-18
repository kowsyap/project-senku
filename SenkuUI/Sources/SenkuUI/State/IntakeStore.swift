import Foundation
import Observation
import SenkuCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// What you ate, and the things you eat often enough to keep a button for.
///
/// The targets are never stored here. They are read from the profile's plan
/// every time they are asked for, so changing your weight or switching from a
/// cut to a bulk moves today's numbers immediately — the same rule the water
/// goal follows, and for the same reason: one source of truth, and no copy to
/// go stale behind your back.
@Observable
public final class IntakeStore {
    static let entriesKey = "senku.intake.entries.v1"
    static let favouritesKey = "senku.intake.favourites.v1"

    private let defaults: UserDefaults
    private let calendar: Calendar

    public private(set) var entries: [IntakeEntry] = []
    public private(set) var favourites: [FoodFavourite] = []

    public init(defaults: UserDefaults = SenkuStorage.shared, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        reload()
    }

    /// Re-reads from the shared container.
    ///
    /// Food can be logged from outside this process — a widget, a shortcut —
    /// and an object loaded once at launch would both miss those and write its
    /// stale array back over them. Every mutation starts here. (Water learned
    /// this the hard way; see `WaterStore.reload`.)
    public func reload() {
        entries = Self.load([IntakeEntry].self, key: Self.entriesKey, from: defaults) ?? []
        favourites = Self.load([FoodFavourite].self, key: Self.favouritesKey, from: defaults) ?? []
    }

    public var log: IntakeLog { IntakeLog(entries, calendar: calendar) }

    // MARK: - The targets

    /// Today's targets, or nil where there is no profile to derive them from.
    ///
    /// Nil rather than a guess: this screen is a comparison, and a comparison
    /// against an invented target is worse than no screen at all. The UI sends
    /// you to the calculator instead.
    public func targets(profile: ProfileStore.Profile?) -> MacroTargets? {
        profile?.plan.macros
    }

    public func day(
        _ date: Date = .now,
        profile: ProfileStore.Profile?
    ) -> IntakeDay? {
        guard let targets = targets(profile: profile) else { return nil }
        return log.day(date, targets: targets)
    }

    // MARK: - Eating

    @discardableResult
    public func add(_ entry: IntakeEntry) -> Bool {
        guard !entry.isEmpty else { return false }

        reload()
        entries.append(entry)
        entries.sort { $0.date > $1.date }
        persistEntries()
        return true
    }

    /// Logs a favourite and counts the use, which is what orders the row.
    @discardableResult
    public func log(_ favourite: FoodFavourite, at date: Date = .now) -> Bool {
        guard let entry = favourite.entry(at: date) else { return false }

        reload()
        if let index = favourites.firstIndex(where: { $0.id == favourite.id }) {
            favourites[index].timesUsed += 1
            persistFavourites()
        }
        return add(entry)
    }

    /// The bare "+40 g protein" case, which is most of the logging most people
    /// will actually do.
    @discardableResult
    public func addProtein(_ grams: Double, at date: Date = .now) -> Bool {
        guard let entry = try? IntakeEntry(date: date, proteinG: grams) else { return false }
        return add(entry)
    }

    /// The other half of the bare case: a calorie figure for something whose
    /// macros you do not know. It moves the calorie ring and leaves the protein
    /// ring alone, which is the honest thing for it to do — a guess at its
    /// protein would be a fiction in the one number this screen exists to keep
    /// straight.
    @discardableResult
    public func addCalories(_ calories: Double, at date: Date = .now) -> Bool {
        guard calories > 0,
              let entry = try? IntakeEntry(date: date, enteredCalories: calories)
        else { return false }
        return add(entry)
    }

    public func update(_ entry: IntakeEntry) {
        reload()
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        entries.sort { $0.date > $1.date }
        persistEntries()
    }

    public func delete(_ entry: IntakeEntry) {
        reload()
        entries.removeAll { $0.id == entry.id }
        persistEntries()
    }

    /// Re-adds an entry by id, for import and for undo — a no-op if it is
    /// already there, so importing the same backup twice does not double it.
    public func restore(_ entry: IntakeEntry) {
        reload()
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        entries.sort { $0.date > $1.date }
        persistEntries()
    }

    // MARK: - Favourites

    /// Most-used first, then alphabetical, so the row is stable between meals
    /// rather than reshuffling under your thumb.
    public var orderedFavourites: [FoodFavourite] {
        favourites.sorted {
            $0.timesUsed == $1.timesUsed
                ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                : $0.timesUsed > $1.timesUsed
        }
    }

    public func save(_ favourite: FoodFavourite) {
        reload()
        if let index = favourites.firstIndex(where: { $0.id == favourite.id }) {
            favourites[index] = favourite
        } else {
            favourites.append(favourite)
        }
        persistFavourites()
    }

    public func delete(_ favourite: FoodFavourite) {
        reload()
        favourites.removeAll { $0.id == favourite.id }
        persistFavourites()
    }

    // MARK: - Streaks

    /// Days the protein target was reached, as start-of-day dates.
    ///
    /// Recomputed against today's targets rather than recorded at the time.
    /// The same trade the water streak makes: a target that changes rewrites
    /// the history, which is the lesser evil next to a history judged against
    /// a number the app can no longer explain.
    public func proteinDays(_ days: Int = 35, profile: ProfileStore.Profile?) -> Set<Date> {
        metDays(days, profile: profile) { $0.isProteinMet }
    }

    /// Days calories landed inside the band. See `IntakeDay.isCaloriesMet` for
    /// why it is a band and not a ceiling.
    public func calorieDays(_ days: Int = 35, profile: ProfileStore.Profile?) -> Set<Date> {
        metDays(days, profile: profile) { $0.isCaloriesMet }
    }

    private func metDays(
        _ days: Int,
        profile: ProfileStore.Profile?,
        where isMet: (IntakeDay) -> Bool
    ) -> Set<Date> {
        guard let targets = targets(profile: profile) else { return [] }

        return Set(
            log.recentDays(days, targets: targets)
                .filter { !$0.isUnlogged && isMet($0) }
                .map { calendar.startOfDay(for: $0.date) }
        )
    }

    // MARK: - Storage

    private func persistEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.entriesKey)
        reloadWidgets()
    }

    private func persistFavourites() {
        guard let data = try? JSONEncoder().encode(favourites) else { return }
        defaults.set(data, forKey: Self.favouritesKey)
        reloadWidgets()
    }

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
