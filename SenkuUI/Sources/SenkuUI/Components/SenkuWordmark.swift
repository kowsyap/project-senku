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
extension Notification.Name {
    /// Posted by a long press on the wordmark. Picked up by ``RootView``.
    ///
    /// A notification rather than a binding threaded through every screen: the
    /// mark is in the toolbar of all of them, and the importer belongs to the
    /// one place that holds every store. Wiring each screen to pass a flag
    /// upwards would put a parameter on views that have nothing to do with it.
    static let senkuImportRequested = Notification.Name("senku.importRequested")
}

/// A long press on the mark opens the data importer.
///
/// Hidden on purpose. It is not a feature you need at the squat rack, it would
/// cost a permanent button on every screen to advertise, and the mark is the
/// one control present on all of them. Held for a full second so that nobody
/// finds it by resting a thumb on the logo.
struct SenkuWordmark: View {
    /// Tied to the text size beside it, so the pair scale together.
    @ScaledMetric(relativeTo: .headline) private var markHeight: CGFloat = 30

    var body: some View {
        HStack(spacing: 6) {
            Image("SenkuMark", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(height: markHeight)

            Text("SENKU")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        // A toolbar hands a text item only as much width as it thinks an icon
        // needs, which truncated the mark to "S(". This takes the width the
        // word actually measures.
        .fixedSize()
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 1.0) {
            Feedback.control()
            NotificationCenter.default.post(name: .senkuImportRequested, object: nil)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Senku")
        .accessibilityAddTraits(.isHeader)
        // VoiceOver has no long press, so the same door is a rotor action.
        .accessibilityAction(named: "Import data") {
            NotificationCenter.default.post(name: .senkuImportRequested, object: nil)
        }
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
