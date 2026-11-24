#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The reminder switch and its two numbers.
struct WaterReminderControls: View {
    @Bindable var store: WaterStore

    var body: some View {
        #if canImport(UserNotifications) && !os(macOS)
        Toggle(isOn: Binding(
            get: { store.settings.remindersOn },
            set: { wanted in
                store.update { $0.remindersOn = wanted }
                Task {
                    let granted = await WaterReminders.schedule(store.settings)
                    // A refused permission puts the switch back rather than
                    // leaving it on and silent.
                    if !granted { store.update { $0.remindersOn = false } }
                }
            }
        )) {
            Text("Remind me to drink")
                .font(.subheadline)
        }

        if store.settings.remindersOn {
            Stepper(value: interval, in: 30...240, step: 30) {
                LabeledContent("Every", value: intervalText)
            }

            Stepper(value: start, in: 5...12) {
                LabeledContent("From", value: "\(store.settings.reminderStartHour):00")
            }

            Stepper(value: end, in: 13...23) {
                LabeledContent("Until", value: "\(store.settings.reminderEndHour):00")
            }

        }
        #endif
    }

    private var intervalText: String {
        let minutes = store.settings.reminderIntervalMinutes
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes)m"
    }

    private var interval: Binding<Int> {
        Binding(
            get: { store.settings.reminderIntervalMinutes },
            set: { value in
                store.update { $0.reminderIntervalMinutes = value }
                reschedule()
            }
        )
    }

    private var start: Binding<Int> {
        Binding(
            get: { store.settings.reminderStartHour },
            set: { value in
                store.update { $0.reminderStartHour = value }
                reschedule()
            }
        )
    }

    private var end: Binding<Int> {
        Binding(
            get: { store.settings.reminderEndHour },
            set: { value in
                store.update { $0.reminderEndHour = value }
                reschedule()
            }
        )
    }

    private func reschedule() {
        #if canImport(UserNotifications) && !os(macOS)
        Task { await WaterReminders.schedule(store.settings) }
        #endif
    }
}
#endif
