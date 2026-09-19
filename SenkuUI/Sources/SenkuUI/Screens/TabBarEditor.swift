#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Which three screens live in the bar.
///
/// Reached from "More", which is where somebody goes when the bar does not have
/// what they want — the moment they are most likely to want to change it.
struct TabBarEditor: View {
    @Bindable var layout: TabLayout

    var body: some View {
        List {
            Section {
                ForEach(TabLayout.selectable) { tab in
                    let isOn = layout.contains(tab)

                    Button {
                        layout.toggle(tab)
                        Feedback.control()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isOn ? tab.tint : Color.secondary)

                            Image(systemName: tab.symbol)
                                .foregroundStyle(isOn ? tab.tint : Color.secondary)
                                .frame(width: 24)

                            Text(tab.title)
                                .foregroundStyle(Color.primary)

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Full and not already chosen: the row would do nothing, so
                    // it says so rather than swallowing the tap.
                    .disabled(layout.isFull && !isOn)
                }
            } header: {
                Text("In the bar")
            } footer: {
                Text(layout.isFull
                     ? "\(layout.slots) at a time on this screen. Turn one off to make room."
                     : "Choose \(layout.slots - layout.chosen.count) more. Everything else stays under More.")
            }

            Section {
                Button("Back to the usual three") { layout.reset() }
            }
        }
        .navigationTitle("Bar")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .senkuBottomBarInset()
    }
}
#endif
