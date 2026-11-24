#if !os(watchOS)
import SwiftUI
import SenkuCore

/// A day's muscle groups as icons in a thin rounded box — how the Week and
/// Workout pages show what a day trains, on the right of its row.
///
/// When the row has no room for them all — a day with many groups on a small
/// phone — the icons scroll sideways inside the box rather than squeezing
/// the day's name out.
struct MuscleGroupBox: View {
    let groups: [WorkoutGroup]
    var size: CGFloat = 18

    var body: some View {
        ViewThatFits(in: .horizontal) {
            icons
            ScrollView(.horizontal, showsIndicators: false) { icons }
                .scrollBounceBehavior(.basedOnSize)
                // At least two icons' worth, so the box never shrinks to a sliver.
                .frame(minWidth: size * 2 + 6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }

    private var icons: some View {
        HStack(spacing: 6) {
            ForEach(Array(Set(groups)).sorted(by: { $0.rawValue < $1.rawValue })) { group in
                GroupGlyph(group: group, size: size)
            }
        }
    }
}
#endif
