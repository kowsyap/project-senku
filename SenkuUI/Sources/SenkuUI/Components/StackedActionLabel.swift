#if !os(watchOS)
import SwiftUI

/// An icon with its name underneath, for a toolbar button.
///
/// A glyph alone is a guess until you press it, and a word beside a glyph eats
/// width a navigation bar has not got. Stacking them buys legibility for a few
/// points of height — the arrangement a tab bar has always used, for the same
/// reason.
///
/// ## Why this is a view and not a `LabelStyle`
///
/// It was a `LabelStyle` first, and nothing changed on screen. A toolbar in
/// iOS 26 renders `Label` its own way and discards the style it is given, so
/// the only reliable way to get two lines is to hand it something that is not a
/// `Label` at all.
///
/// `fixedSize` is not optional either: a toolbar measures an item as though it
/// were a single icon, which truncates anything wider — already good for one
/// build in which this app's own name rendered as "S(".
struct StackedActionLabel: View {
    let title: String
    let symbol: String

    init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.system(size: 9, weight: .semibold))
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
#endif
