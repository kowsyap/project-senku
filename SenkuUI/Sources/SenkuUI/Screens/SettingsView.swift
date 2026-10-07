#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Settings that belong to the app rather than to any one screen.
///
/// Water, food and the plate rack keep theirs behind the gear on their own
/// pages, because that is where you are standing when you want to change them.
/// What lives here is what has no page of its own: how the app is arranged,
/// and — once it exists — what it shares with Apple Health.
///
/// A list of links rather than the settings themselves inline, so that adding a
/// group later is a row, not a redesign of a screen people already know.
struct SettingsView: View {
    @Bindable var layout: TabLayout

    var body: some View {
        List {
            Section {
                NavigationLink {
                    TabBarEditor(layout: layout)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(RootView.Tab.more.tint)
                            .frame(width: 26)
                        Text("Navbar")
                    }
                }
            }
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .senkuBottomBarInset()
    }
}
#endif
