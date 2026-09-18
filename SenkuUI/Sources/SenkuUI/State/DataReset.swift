import Foundation
import SenkuCore

/// Wipes everything Senku has stored.
///
/// ## Why it deletes by prefix rather than by a list of keys
///
/// A list of keys is a list that will be wrong. Every feature so far has
/// brought its own storage key — profile, weight log, records, custom
/// exercises, plan, live workout, history — and the next one will too, and a
/// reset that quietly left the new feature's data behind would be the worst
/// kind of bug: invisible until someone reset the app *because* something was
/// wrong with that data, and found it still there.
///
/// Every key the app writes begins `senku.`, so that is the rule. It also
/// clears the same prefix from `.standard`, where a profile written before the
/// App Group existed may still be sitting.
public enum DataReset {
    /// Everything stored, gone. The caller is responsible for asking first.
    public static func wipe(_ defaults: UserDefaults = SenkuStorage.shared) {
        for store in [defaults, .standard] {
            for key in store.dictionaryRepresentation().keys where key.hasPrefix("senku.") {
                store.removeObject(forKey: key)
            }
        }

        // The rest timer is not only in `UserDefaults`: a running one has a
        // notification scheduled with the system and, on the phone, a Live
        // Activity on the lock screen. Clearing the key alone would leave both
        // counting down for a timer nothing in the app remembers starting.
        #if canImport(UserNotifications) && !os(macOS)
        RestNotifications.cancel()
        #endif
    }
}
