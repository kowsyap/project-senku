import Foundation

/// The settings a backup carries, and the two small records that live beside
/// them.
///
/// ## Copied as stored, by key
///
/// Each of these is already written to the App Group in its own shape — a JSON
/// blob, a string, a list, a switch — and the stores that own them know how to
/// read it. So the backup takes each one as it is stored and puts it back the
/// same way, rather than inventing a second, hand-written shape for every
/// setting that would then have to be kept in step with the first.
///
/// ## What is left out, on purpose
///
/// - **The Gemini key.** It is in the Keychain precisely so that it is never in
///   a file like this one.
/// - **A running rest timer.** It is a countdown, not a setting; restoring one
///   from last week would be an alarm for a set long finished.
/// - **The iPad sidebar arrangement.** It belongs to the device it was made on.
/// - **"Already seeded" markers**, which only mean something to the install
///   that wrote them.
public struct SettingsBackup: Codable, Equatable, Sendable {
    public enum Value: Codable, Equatable, Sendable {
        case data(Data)
        case string(String)
        case strings([String])
        case bool(Bool)
    }

    /// Everything carried. A key added here is backed up and restored; a key
    /// left out is not — there is no third case.
    static let keys: [String] = [
        // Water: containers, goal, reminder window, whether creatine is taken.
        "senku.water.settings.v1",
        // Records rather than settings, but stored as raw blobs like these and
        // otherwise in no backup at all.
        "senku.water.creatineDays.v1",
        "senku.forgivenDays.v1",
        // The gym.
        "senku.plates.v1",
        "senku.plates.unit.v1",
        // The bar.
        "senku.tabs.visible.v2",
        "senku.tabs.hidden.v1",
        // Ring or body, in the exercise picker.
        "senku.picker.groupStyle.v1",
        // Whether a logged set starts a rest, and for how long.
        "senku.restAfterSet.v1",
        // Reminder switches. Restoring one also books it — see RootView.
        "senku.weightReminder.v1",
        "senku.creatineReminder.v1",
        // What the last export included.
        "senku.report.selection.v1",
    ]

    public var values: [String: Value]

    public init(values: [String: Value] = [:]) {
        self.values = values
    }

    /// What this device has set. Keys never written are left out, so a
    /// restore does not overwrite a choice with a default.
    public static func capture(from defaults: UserDefaults = SenkuStorage.shared) -> SettingsBackup {
        var values: [String: Value] = [:]
        for key in keys {
            switch defaults.object(forKey: key) {
            case let data as Data: values[key] = .data(data)
            case let text as String: values[key] = .string(text)
            case let list as [String]: values[key] = .strings(list)
            case let number as NSNumber: values[key] = .bool(number.boolValue)
            default: break
            }
        }
        return SettingsBackup(values: values)
    }

    /// Writes them back. Anything the file names that is not on the list is
    /// ignored — a backup is not a way to set arbitrary keys.
    ///
    /// - Returns: whether anything was written.
    @discardableResult
    public func apply(to defaults: UserDefaults = SenkuStorage.shared) -> Bool {
        var wrote = false
        for (key, value) in values where Self.keys.contains(key) {
            switch value {
            case .data(let data): defaults.set(data, forKey: key)
            case .string(let text): defaults.set(text, forKey: key)
            case .strings(let list): defaults.set(list, forKey: key)
            case .bool(let flag): defaults.set(flag, forKey: key)
            }
            wrote = true
        }
        return wrote
    }
}
