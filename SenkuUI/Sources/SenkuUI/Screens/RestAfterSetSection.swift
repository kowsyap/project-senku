#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The rest that follows a logged set: whether there is one, and how long.
///
/// On the Workout tab's Week page, beside the target each exercise aims for —
/// it is about how a workout runs, and that is where you are when you think
/// about it — and reached from Settings through the same page.
struct RestAfterSetSection: View {
    @State private var setting = RestAfterSet.load()

    var body: some View {
        Section {
            Toggle(isOn: $setting.isOn) {
                Text("Start rest after each set")
            }
            .tint(RootView.Tab.rest.tint)

            if setting.isOn {
                Picker("Rest", selection: $setting.seconds) {
                    ForEach(RestPreset.allCases) { preset in
                        Text(preset.title).tag(preset.duration)
                    }
                }
            }
        } header: {
            Text("Rest")
        }
        .onChange(of: setting) { _, changed in changed.save() }
    }
}
#endif
