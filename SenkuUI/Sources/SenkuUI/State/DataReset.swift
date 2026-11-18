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
    ///
    /// What is scheduled with the system goes first, while the switches that
    /// say what is on are still there to read; the keys go after, so nothing
    /// a cancel writes back on its way out survives.
    @MainActor
    public static func wipe(_ defaults: UserDefaults = SenkuStorage.shared) {
        #if canImport(UserNotifications) && !os(macOS)
        // The rest timer is not only in `UserDefaults`: a running one has a
        // notification scheduled with the system and, on the phone, a Live
        // Activity on the lock screen and a chime. Clearing the key alone would
        // leave them counting down for a timer nothing in the app remembers.
        RestNotifications.cancel()
        #if os(iOS)
        RestChime.cancel()
        RestActivityController.shared.end(dismissing: .immediate)
        #endif
        // Every reminder likewise: a wiped app should not keep reminding you
        // to weigh in, drink, take creatine or pay a bill it no longer has.
        WeightReminder.disable()
        CreatineReminder.disable()
        WaterReminders.cancelAll()
        Task { await DueReminders.cancelAll() }
        #endif

        for store in [defaults, .standard] {
            for key in store.dictionaryRepresentation().keys where key.hasPrefix("senku.") {
                store.removeObject(forKey: key)
            }
        }

        #if !os(watchOS)
        // Progress photos are files, not defaults.
        ProgressPhotoStore.wipe()
        // The Gemini key is in the Keychain, which outlives the defaults.
        _ = GeminiAccount.clear()
        #endif
    }
}
