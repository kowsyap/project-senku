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

    /// Five or six of them, chosen by the person using it — see ``TabLayout``,
    /// which only ever hands over as many as this can hold.
    let tabs: [RootView.Tab]

    @Namespace private var glassNamespace

    /// Where each item sits in the row, so a finger dragged across the bar can
    /// be turned back into a tab.
    @State private var frames: [RootView.Tab: CGRect] = [:]

    private static let space = "senku.tabbar"

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
                            // The same weight of tint as every other pill —
                            // glass, not paint. A near-solid black read as a
                            // sticker on top of the bar rather than part of it.
                            ? .regular.tint(
                                tab.wantsDarkPill
                                    ? Color.black.opacity(0.32)
                                    : tab.tint.opacity(0.28)
                              ).interactive()
                            : .identity,
                        in: .capsule
                    )
                    .glassEffectID(tab, in: glassNamespace)
            }
            .glassEffect(.regular, in: .capsule)
        }
        .frame(maxWidth: .infinity)          // centres the capsule, does not stretch it
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Before Liquid Glass

    private var legacyBar: some View {
        scroller { item($0) }
            .background(.bar, in: .capsule)
            .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
    }

    // MARK: - Shared

    /// The scrolling row itself, with the decoration left to the caller.
    /// The row itself, as wide as what is in it.
    ///
    /// It used to be a horizontal `ScrollView`, which takes the whole width
    /// whether it needs it or not — so four tabs sat in a bar sized for nine,
    /// adrift in their own capsule. The slot count is capped at what fits, so
    /// there is nothing left to scroll: an `HStack` hugs its contents and the
    /// capsule shrinks to them, centred.
    private func scroller<Item: View>(
        @ViewBuilder item: @escaping (RootView.Tab) -> Item
    ) -> some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.self) { tab in
                item(tab)
                    .id(tab)
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(Self.space))
                    } action: { frame in
                        frames[tab] = frame
                    }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .coordinateSpace(name: Self.space)
        // Put a finger on the bar and slide: the selection follows it, the way
        // the pill itself suggests it might. A tap is unaffected — this only
        // starts once the finger has actually travelled.
        .gesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .named(Self.space))
                .onChanged { drag in select(under: drag.location) }
                .onEnded { drag in select(under: drag.location) }
        )
    }

    /// The tab under a point, if the point is on one.
    ///
    /// Horizontal only: the row is a row, and a finger that wanders above or
    /// below it on the way across is still pointing at the same thing.
    private func select(under point: CGPoint) {
        guard let tab = frames.first(where: { _, frame in
            point.x >= frame.minX && point.x <= frame.maxX
        })?.key, tab != selection else { return }

        Feedback.control()
        withAnimation(.snappy(duration: 0.25)) {
            selection = tab
        }
    }

    private func selected(_ tab: RootView.Tab) -> Bool { tab == selection }

    private func item(_ tab: RootView.Tab) -> some View {
        let isOn = selected(tab)

        return Button {
            guard !isOn else { return }
            Feedback.control()
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
                    // A template, so it takes the row's colour like every
                    // other icon here: grey while it waits its turn, gold only
                    // when it is the tab you are on.
                    Image(mark, bundle: .module)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 21)
                } else {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 18, weight: isOn ? .semibold : .regular))
                        .frame(height: 21)
                }

                Text(tab.title)
                    .font(.system(size: 10, weight: isOn ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize()
                    // Gold reads on a dark pill at icon size and turns to mud
                    // at ten points. The mark keeps the colour; the word takes
                    // the contrast.
                    .foregroundStyle(
                        isOn && tab.wantsDarkPill
                            ? AnyShapeStyle(.white)
                            : AnyShapeStyle(.foreground)
                    )
            }
            .foregroundStyle(isOn ? AnyShapeStyle(tab.activeTint) : AnyShapeStyle(.secondary))
            // Wide enough to read as a column, narrow enough that five of them
            // fit a phone without the row scrolling. Seventy was sized for a
            // bar that scrolled anyway; five fixed positions have to fit.
            .frame(minWidth: 56)
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
