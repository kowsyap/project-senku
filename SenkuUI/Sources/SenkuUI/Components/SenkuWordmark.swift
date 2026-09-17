#if !os(watchOS)
import SwiftUI

/// The app's mark, worn at the top of every screen: the icon's own character,
/// beside the name set in type.
///
/// The character comes from the app icon with its plate removed, so the icon on
/// the Home Screen and the mark inside the app are recognisably the same thing.
/// The **name** stays as type rather than as part of the image — the artwork's
/// own "SENKU" is pale, which would be invisible on a light background and
/// frozen against Dynamic Type. Type follows the theme; a PNG cannot.
struct SenkuWordmark: View {
    /// Tied to the text size beside it, so the pair scale together.
    @ScaledMetric(relativeTo: .headline) private var markHeight: CGFloat = 22

    var body: some View {
        HStack(spacing: 5) {
            Image("SenkuMark", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(height: markHeight)

            Text("SENKU")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        // A toolbar hands a text item only as much width as it thinks an icon
        // needs, which truncated the mark to "S(". This takes the width the
        // word actually measures.
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Senku")
        .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Puts the mark in the navigation bar's leading slot.
    ///
    /// On iOS 26 a toolbar item is given a glass capsule of its own, which is
    /// right for a button and wrong for a logo — it made the app look as though
    /// its name were a control you could press. `sharedBackgroundVisibility`
    /// takes the capsule away and leaves the mark sitting on the bar.
    func senkuWordmark() -> some View {
        toolbar {
            #if os(iOS)
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarLeading) { SenkuWordmark() }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarLeading) { SenkuWordmark() }
            }
            #else
            ToolbarItem(placement: .navigation) { SenkuWordmark() }
            #endif
        }
    }
}
#endif
