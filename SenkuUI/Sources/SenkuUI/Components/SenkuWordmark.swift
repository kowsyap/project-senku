#if !os(watchOS)
import SwiftUI

/// The app's name, worn at the top of every screen.
///
/// Drawn rather than drawn *from an asset*: it is a wordmark, and keeping it as
/// type means it scales with Dynamic Type, inverts correctly in dark mode and
/// costs the package no image to ship. The mark sits in the leading slot so it
/// reads as whose app this is, while the navigation title goes on saying which
/// screen you are looking at.
struct SenkuWordmark: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Senku.Palette.protein)

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
    /// Puts the wordmark in the navigation bar's leading slot.
    func senkuWordmark() -> some View {
        toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) { SenkuWordmark() }
            #else
            ToolbarItem(placement: .navigation) { SenkuWordmark() }
            #endif
        }
    }
}
#endif
