#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Everything about water that is decided once.
///
/// Off the main screen entirely. That screen is opened six times a day for two
/// seconds each, and a card of switches at the bottom of it is a card scrolled
/// past six times a day — while a gear in the corner costs one tap on the rare
/// occasion any of this changes.
struct WaterSettingsView: View {
    @Bindable var store: WaterStore

    #if canImport(UserNotifications) && !os(macOS)
    @State private var remindingCreatine = CreatineReminder.isOn
    #endif

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { store.settings.takesCreatine },
                    set: { taking in store.update { $0.takesCreatine = taking } }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("I take creatine")
                        Text("Adds \(Int(WaterGoal.creatineExtraML)) ml to the daily target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                #if canImport(UserNotifications) && !os(macOS)
                if store.settings.takesCreatine {
                    Toggle(isOn: $remindingCreatine) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remind me to take it")
                            Text("Every day at \(CreatineReminder.hour):00")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                #endif
            } header: {
                Text("Creatine")
            } footer: {
                Text("Creatine draws water into muscle, so the target goes up while you are taking it. Turning this on also puts a daily tick on the water screen.")
            }

            Section {
                WaterReminderControls(store: store)
            } header: {
                Text("Reminders")
            }

            Section {
                ForEach(store.settings.containers) { container in
                    HStack(spacing: 12) {
                        VesselIcon(vessel: .forSize(container.millilitres), size: 20)
                            .frame(width: 24, height: 22)
                            .foregroundStyle(Senku.Palette.deficit)

                        // The name is fixed. Three vessels named glass, bottle
                        // and jug are what everyone has, the icon follows the
                        // size rather than the word, and a renameable label is
                        // a field to fill in for no gain.
                        Text(container.name)

                        Spacer(minLength: 8)

                        TextField("250", value: size(of: container), format: .number)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 64)
                            .monospacedDigit()
                        Text("ml").foregroundStyle(.secondary)
                    }
                }
            } header: {
                // Three, fixed, and named. The water screen's whole value is
                // that a drink is one tap, and a row of five or six buttons is
                // a row you have to read before tapping — at which point it is
                // no faster than typing the amount.
                Text("What you drink from")
            }
        }
        #if canImport(UserNotifications) && !os(macOS)
        .onChange(of: remindingCreatine) { _, wanted in
            Task {
                if wanted {
                    // Put back if permission is refused, rather than left on
                    // and silent.
                    let granted = await CreatineReminder.enable()
                    if !granted { remindingCreatine = false }
                } else {
                    CreatineReminder.disable()
                }
            }
        }
        .onChange(of: store.settings.takesCreatine) { _, taking in
            // Dropping creatine takes its reminder with it: a nudge for a
            // supplement you no longer take is how notifications get turned off
            // wholesale.
            Task {
                await CreatineReminder.refresh(takesCreatine: taking)
                remindingCreatine = CreatineReminder.isOn
            }
        }
        .task {
            // Re-booked on every visit, like the weigh-in reminder: a pending
            // request can be lost to a restore while the switch still says it
            // is on.
            await CreatineReminder.refresh(takesCreatine: store.settings.takesCreatine)
            remindingCreatine = CreatineReminder.isOn
        }
        #endif
        .navigationTitle("Water Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // The number pad has no return key, so without this a size can be
        // typed and not left.
        .dismissableKeyboard()
        .senkuBottomBarInset()
    }

    private func size(of container: WaterContainer) -> Binding<Double> {
        Binding(
            get: { container.millilitres },
            set: { newSize in
                store.update { settings in
                    guard let index = settings.containers.firstIndex(where: { $0.id == container.id })
                    else { return }
                    settings.containers[index].millilitres = max(1, newSize)
                }
            }
        )
    }
}
#endif
