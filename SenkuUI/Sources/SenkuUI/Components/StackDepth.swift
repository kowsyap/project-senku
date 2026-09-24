#if !os(watchOS)
import SwiftUI

/// Whether a tab's screen has pushed anything on top of itself.
///
/// ## Why this exists
///
/// Tapping a tab is understood to mean "take me to the front of this one", and
/// the front is reached by rebuilding that tab's navigation stack — the pushes
/// here are `navigationDestination(isPresented:)`, which leave nothing in a
/// `NavigationPath` to pop.
///
/// Rebuilding a stack that is *already* at its front is the problem this
/// solves. Nothing moves, but the screen is torn down and built again, and it
/// reads as an unexplained flicker on a tap that should have done nothing at
/// all. So the screens say whether they are deep, and a tap only rebuilds when
/// there is something to come back from.
struct SenkuStackDepthKey: PreferenceKey {
    static let defaultValue = 0

    static func reduce(value: inout Int, nextValue: () -> Int) {
        value = max(value, nextValue())
    }
}

extension View {
    /// Reports that this screen has pushed something.
    ///
    /// Takes the flags a screen already keeps for its own pushes, so nothing
    /// has to be tracked twice: anything true means there is a way back.
    func senkuPushed(_ isPushed: Bool...) -> some View {
        preference(key: SenkuStackDepthKey.self, value: isPushed.contains(true) ? 1 : 0)
    }
}
#endif
