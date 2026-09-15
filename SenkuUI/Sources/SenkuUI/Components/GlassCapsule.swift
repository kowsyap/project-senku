#if !os(watchOS)
import SwiftUI

/// A capsule that reads as tinted glass.
///
/// On iOS 26 this is Liquid Glass proper — the system material refracts and
/// reacts to touch, and it is worth using rather than imitating. Older systems
/// get the nearest honest thing: a thin material capsule with the same tint and
/// a hairline edge.
struct GlassCapsule: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(tint.opacity(0.22)).interactive(),
                    in: .capsule
                )
                .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        } else {
            content
                .background(tint.opacity(0.14), in: .capsule)
                .background(.ultraThinMaterial, in: .capsule)
                .overlay {
                    Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        }
    }
}

extension View {
    func glassCapsule(tint: Color) -> some View {
        modifier(GlassCapsule(tint: tint))
    }
}
#endif
