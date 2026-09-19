#if !os(watchOS)
import SwiftUI
import SenkuCore

/// What the bar carries, in what order — and the order of everything else.
///
/// Reached from "More", which is where somebody goes when the bar does not have
/// what they want: the moment they are most likely to want to change it.
///
/// ## Why two lists rather than one with a line through it
///
/// The obvious design is a single ordered list where the first few are "in the
/// bar". It reads well and behaves badly: dragging one item across the line
/// silently demotes another, so a rearrangement you meant as a reorder turns
/// into a swap you did not ask for. Two lists make the boundary a thing you
/// cross on purpose, with a tap.
struct TabBarEditor: View {
    @Bindable var layout: TabLayout

    var body: some View {
        List {
            Section {
                ForEach(layout.chosen) { tab in
                    row(tab, isInBar: true)
                }
                .onMove { offsets, destination in
                    layout.moveInBar(from: offsets, to: destination)
                }
            } header: {
                Text("In the bar")
            }

            Section {
                ForEach(layout.others) { tab in
                    row(tab, isInBar: false)
                }
                .onMove { offsets, destination in
                    layout.moveInMore(from: offsets, to: destination)
                }
            } header: {
                Text("Under More")
            }

            Section {
                Button("Reset to default") { layout.reset() }
            } footer: {
                Text("Up to \(layout.slots) in the navbar on this screen. Drag to arrange.")
            }
        }
        .navigationTitle("Navbar settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .senkuBottomBarInset()
    }

    /// One screen, with the button that moves it across.
    ///
    /// The circle is the only tappable part while editing, because a row that
    /// both drags and toggles will do the wrong one of the two often enough to
    /// be annoying.
    private func row(_ tab: RootView.Tab, isInBar: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                layout.toggle(tab)
                Feedback.control()
            } label: {
                Image(systemName: isInBar ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isInBar ? Senku.Palette.warning : Senku.Palette.surplus)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            // Full, and this one is not in it: the tap would do nothing, so it
            // says so rather than swallowing it.
            .disabled(!isInBar && layout.isFull)
            .opacity(!isInBar && layout.isFull ? 0.35 : 1)

            Image(systemName: tab.symbol)
                .foregroundStyle(tab.tint)
                .frame(width: 24)

            Text(tab.title)
                .foregroundStyle(Color.primary)

            Spacer()
        }
    }
}
#endif
