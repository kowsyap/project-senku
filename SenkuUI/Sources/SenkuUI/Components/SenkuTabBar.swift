#if os(iOS)
import SwiftUI

/// A tab bar that scrolls sideways instead of hiding tabs behind "More".
///
/// ## Why this exists at all
///
/// UIKit gives an iPhone five slots and puts everything after them inside a
/// "More" list. That list is where features go to be forgotten: it is two taps
/// deep, it is a plain table with none of the app's colour, and the tab that
/// lands in it is chosen by position rather than by how much anybody uses it.
/// With six destinations and more coming — water, macros — Senku would be
/// permanently one feature away from burying one.
///
/// So the bar scrolls. Every destination stays a single tap away, at the same
/// size, in the same colours, and the sixth is reached by a flick rather than a
/// menu. What is given up is the system's own customisation — reordering and
/// pinning came free with `TabViewCustomization` and cannot be had here — which
/// is a real loss, and the reason iPad and Mac keep the system sidebar: they
/// have the width to show everything at once, and nothing to gain from this.
///
/// ## Drawn as glass, not as a panel
///
/// On iOS 26 the system tab bar is a floating capsule of Liquid Glass that the
/// content scrolls *under*, not an opaque strip the content stops above. This
/// is built from the same material — `glassEffect` inside a
/// `GlassEffectContainer`, so the selected tab's own capsule merges with the
/// bar's rather than sitting on top of it as a separate pane of glass, which is
/// what the container is for.
///
/// The selected capsule is tinted with the tab's colour. That is the one place
/// this deliberately does more than the system bar: with six destinations and
/// no labels visible at a glance, colour is the fastest way to know where you
/// are, and the app already gives every screen one.
///
/// Older systems fall back to the material bar, which is what they had anyway.
struct SenkuTabBar: View {
    @Binding var selection: RootView.Tab

    @Namespace private var glassNamespace

    private let tabs = RootView.Tab.ordered

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                glassBar
            } else {
                legacyBar
            }
        }
    }

    // MARK: - Liquid Glass

    @available(iOS 26.0, *)
    private var glassBar: some View {
        GlassEffectContainer(spacing: 18) {
            scroller { tab in
                item(tab)
                    .glassEffect(
                        selected(tab)
                            ? .regular.tint(tab.tint.opacity(0.28)).interactive()
                            : .identity,
                        in: .capsule
                    )
                    .glassEffectID(tab, in: glassNamespace)
            }
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Before Liquid Glass

    private var legacyBar: some View {
        scroller { item($0) }
            .background(.bar, in: .capsule)
            .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
    }

    // MARK: - Shared

    /// The scrolling row itself, with the decoration left to the caller.
    private func scroller<Item: View>(
        @ViewBuilder item: @escaping (RootView.Tab) -> Item
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs, id: \.self) { tab in
                        item(tab).id(tab)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            // The glass capsule is the clip, so the row must not add one of its
            // own — a second clip inside the first crops the tinted selection
            // against a straight edge.
            .scrollClipDisabled()
            // Selecting a tab that is half off the edge brings it fully in —
            // otherwise the bar tells you where you are with something you
            // cannot entirely see.
            .onChange(of: selection) { _, tab in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(tab, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
        }
        .frame(height: 58)
    }

    private func selected(_ tab: RootView.Tab) -> Bool { tab == selection }

    private func item(_ tab: RootView.Tab) -> some View {
        let isOn = selected(tab)

        return Button {
            guard !isOn else { return }
            // No haptic here: the pager ticks on every landing, however the
            // page was reached, and two taps for one press feels like a stutter.
            withAnimation(.snappy(duration: 0.3)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 3) {
                // "Me" wears a face rather than the system's anonymous
                // silhouette — it is the one tab that is about a particular
                // person. Full colour, so it is not tinted into the bar's
                // accent and lost.
                if let mark = tab.mark {
                    // Drawn as a template and filled, so it takes a colour
                    // rather than staying the ink it was drawn in — Super
                    // Saiyan Blue, which is the one shade the character is
                    // actually associated with.
                    Image(mark, bundle: .module)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 21)
                        .foregroundStyle(Senku.Palette.saiyanBlue)
                        .opacity(isOn ? 1 : 0.6)
                } else {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 18, weight: isOn ? .semibold : .regular))
                        .frame(height: 21)
                }

                Text(tab.title)
                    .font(.system(size: 10, weight: isOn ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(isOn ? AnyShapeStyle(tab.tint) : AnyShapeStyle(.secondary))
            // Wide enough for the longest label, so the row reads as even
            // columns rather than as text of varying width.
            .frame(minWidth: 70)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
#endif

#if os(iOS)
private struct SenkuBottomInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// How much room the floating tab bar needs at the bottom of a screen.
    ///
    /// Carried in the environment rather than passed down, because the screens
    /// that need it are several layers inside a `NavigationStack` and some of
    /// them are pushed destinations that nothing in `RootView` holds a
    /// reference to.
    var senkuBottomInset: CGFloat {
        get { self[SenkuBottomInsetKey.self] }
        set { self[SenkuBottomInsetKey.self] = newValue }
    }
}

extension View {
    /// Keeps a screen's own content clear of the floating tab bar.
    ///
    /// ## Why every screen has to ask for this
    ///
    /// The obvious thing — one `safeAreaInset` around the whole tab container —
    /// does nothing at all. A `NavigationStack` establishes its own safe area
    /// for the screens inside it and does not pass a parent's inset through, so
    /// the lists went on ending underneath the bar with their last rows
    /// unreachable. Raising the inset to 260pt changed nothing, which is how
    /// this was finally pinned down: the inset was not being ignored by a
    /// margin, it was not arriving.
    ///
    /// So the padding is applied *inside* each stack, by the screen itself.
    /// The height still comes from one measured place, through the environment.
    func senkuBottomBarInset() -> some View {
        modifier(SenkuBottomBarInset())
    }
}

private struct SenkuBottomBarInset: ViewModifier {
    @Environment(\.senkuBottomInset) private var inset

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: inset)
        }
    }
}
#endif

#if !os(iOS)
import SwiftUI

extension View {
    /// Nothing to get clear of: the scrolling bar is an iPhone arrangement, and
    /// every other platform uses the system's own navigation. Defined all the
    /// same so the screens that call it need no `#if` of their own.
    func senkuBottomBarInset() -> some View { self }
}
#endif
