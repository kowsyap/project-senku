#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The mark for a muscle group: your artwork if it is there, an SF Symbol if
/// it is not.
///
/// ## Why the fallback
///
/// SF Symbols has no chest, lat or delt icon, so the built-in glyphs can only
/// gesture at the *movement* a group is trained by. An anatomical silhouette
/// says the thing itself, and is recognised without being read — but it has to
/// be drawn, and drawing six of them is not something code can do well.
///
/// So this looks for an image named `muscle.<group>` in the package's asset
/// catalogue and uses it when it exists, tinted as a template so one set of
/// black silhouettes serves both themes and every group colour. Adding the
/// artwork is then a matter of dropping files in; nothing here changes, and
/// nothing breaks in the meantime.
struct GroupGlyph: View {
    let group: WorkoutGroup
    var size: CGFloat = 15

    private var artworkName: String { "muscle.\(group.rawValue)" }

    private var hasArtwork: Bool {
        #if canImport(UIKit)
        UIImage(named: artworkName, in: .module, compatibleWith: nil) != nil
        #elseif canImport(AppKit)
        Bundle.module.image(forResource: artworkName) != nil
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if hasArtwork {
                Image(artworkName, bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: group.symbol)
                    .font(.system(size: size, weight: .semibold))
            }
        }
        .foregroundStyle(group.tint)
        .accessibilityHidden(true)
    }
}
#endif
