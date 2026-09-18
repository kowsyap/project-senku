import Foundation

/// What goes into an export.
///
/// Everything is on by default: the common case is "give me all of it", and a
/// picker that starts empty makes you assemble your own record before you can
/// have one. The switches exist for the other case — sending a coach your
/// training without your anime list, or a weight history without the food log.
///
/// Remembered between exports, because whoever turns anime off is going to turn
/// it off every time.
public struct ReportSelection: Codable, Hashable, Sendable {
    public var profile = true
    public var weight = true
    public var records = true
    public var plan = true
    public var workouts = true
    public var water = true
    public var food = true
    public var anime = true

    /// Charts alongside the figures. Separate from the sections rather than one
    /// per section: it is a question about how the report should look, not
    /// about what it should contain, and nobody wants eight of those.
    public var charts = true

    /// The backup file that rides along with the PDF. Not part of the report at
    /// all — it is the thing "Import Data" takes back — but it is shared in the
    /// same breath, so it is switched off in the same place.
    public var backup = true

    public init() {}

    /// Every section off — the state the Export button refuses.
    public var isEmpty: Bool {
        !profile && !weight && !records && !plan && !workouts && !water && !food && !anime
    }

    /// Nothing at all to share, report or backup.
    public var producesNothing: Bool { isEmpty && !backup }

    // MARK: - Remembering

    static let storageKey = "senku.report.selection.v1"

    public static func load(from defaults: UserDefaults = SenkuStorage.shared) -> ReportSelection {
        guard let data = defaults.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(ReportSelection.self, from: data)
        else { return ReportSelection() }
        return stored
    }

    public func save(to defaults: UserDefaults = SenkuStorage.shared) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
