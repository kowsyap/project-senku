#if os(iOS)
import SwiftUI

/// The bar: five or six screens, and one pill that slides between them.
///
/// ## What it is not
///
/// It is not a `TabView`'s bar. That was tried both ways — first a row that
/// scrolled sideways so nine destinations could each keep a slot, then a paging
/// `TabView` so the pages could be swiped — and both were taken out again. Nine
/// tabs meant reading the bar before using it; the pager rebuilt itself
/// whenever the bar's contents changed and showed a blank page mid-edit. What
/// is left is the thing that was actually wanted: a few fixed positions you can
/// hit without looking, and everything else behind "More".
///
/// ## The pill belongs to the bar, not to a tab
///
/// A tint applied to the selected item can only ever be on one item or another,
/// so it cannot sit between two of them — and sitting between two of them is
/// the whole point of dragging. So the highlight is one capsule drawn behind
/// the row and positioned by hand: it follows a finger exactly while one is
/// down, and springs to whatever it was left on when the finger lifts.
///
/// One gesture does everything, because two cannot share a short distance. The
/// items were buttons once, and a drag to the tab *next door* ended inside the
/// neighbouring button's slop: the tap won and put the selection back where it
/// started, while a drag two tabs over was far enough to escape. A tap is now
/// simply a drag that went nowhere, which is also what a tap is. VoiceOver
/// keeps its own way in — each item carries the button trait and an action.
///
/// ## Drawn as glass, not as a panel
///
/// On iOS 26 the system tab bar is a floating capsule of Liquid Glass that the
/// content scrolls *under*, not an opaque strip the content stops above. This
/// is built from the same material — `glassEffect` inside a
/// `GlassEffectContainer`, so the pill merges with the bar's own glass rather
/// than sitting on top of it as a separate pane, which is what the container is
/// for. The pill carries a single `glassEffectID` for its whole life, so the
/// container treats it as one piece of glass moving rather than a shape
/// appearing somewhere else.
///
/// Older systems fall back to the material bar, which is what they had anyway.
struct SenkuTabBar: View {
    @Binding var selection: RootView.Tab

    /// Five or six of them, chosen by the person using it — see ``TabLayout``,
    /// which only ever hands over as many as this can hold.
    let tabs: [RootView.Tab]

    /// Where each item sits in the row, so a finger dragged across the bar can
    /// be turned back into a tab.
    @State private var frames: [RootView.Tab: CGRect] = [:]

    /// Where the finger is, while it is down. The pill follows this rather than
    /// the selection, which is what makes it feel attached to the finger rather
    /// than chasing it from position to position.
    @State private var dragX: CGFloat?

    @Namespace private var glassNamespace

    // `nonisolated` because the geometry callbacks that name this space are
    // `@Sendable`, and a constant string has nothing to protect.
    nonisolated private static let space = "senku.tabbar"

    /// How the pill travels when it is not being held: a spring with a little
    /// give in it, which is the liquid-glass movement the bar had when it was
    /// morphing a tint from one item to the next.
    private static let settle = Animation.spring(response: 0.34, dampingFraction: 0.72)

    /// The tab the pill is currently over: what a finger is pointing at while
    /// it drags, and the selection when it is not.
    private var highlighted: RootView.Tab {
        guard let dragX, let tab = tab(atX: dragX) else { return selection }
        return tab
    }

    /// The tab nearest a point, by centre.
    ///
    /// Nearest rather than "the one containing it": there are four points of
    /// gap between items, and a finger lifted in one of them belongs to
    /// whichever is closer rather than to nobody. Running off either end lands
    /// on the end item for the same reason.
    private func tab(atX x: CGFloat) -> RootView.Tab? {
        tabs
            .compactMap { tab in frames[tab].map { (tab, abs($0.midX - x)) } }
            .min { $0.1 < $1.1 }?.0
    }

    /// Where the pill is drawn: under the finger while dragging, and around the
    /// selected item when not.
    private var pill: CGRect? {
        guard let frame = frames[highlighted] else { return nil }
        guard let dragX else { return frame }

        // Centred on the finger, but never further out than the row's own ends.
        let half = frame.width / 2
        let low = (tabs.first.flatMap { frames[$0] }?.minX ?? frame.minX) + half
        let high = (tabs.last.flatMap { frames[$0] }?.maxX ?? frame.maxX) - half
        let centre = min(max(dragX, low), high)

        return CGRect(x: centre - half, y: frame.minY, width: frame.width, height: frame.height)
    }

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
            row { item($0) }
                .background(alignment: .topLeading) {
                    // One pill that moves, rather than a tint that jumps from
                    // item to item. It is what lets a finger drag it: a
                    // highlight belonging to an item can only ever be on one
                    // item or another, and this belongs to the bar.
                    if let pill {
                        Color.clear
                            .frame(width: pill.width, height: pill.height)
                            .glassEffect(
                                .regular.tint(
                                    highlighted.wantsDarkPill
                                        ? Color.black.opacity(0.32)
                                        : highlighted.tint.opacity(0.28)
                                ).interactive(),
                                in: .capsule
                            )
                            // One id for the life of the bar: the container
                            // then treats this as a single piece of glass
                            // moving, and gives it the stretch it used to have
                            // morphing from item to item.
                            .glassEffectID("senku.tabbar.pill", in: glassNamespace)
                            .offset(x: pill.minX, y: pill.minY)
                    }
                }
                .glassEffect(.regular, in: .capsule)
        }
        .frame(maxWidth: .infinity)          // centres the capsule, does not stretch it
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Before Liquid Glass

    private var legacyBar: some View {
        row { item($0) }
            .background(alignment: .topLeading) {
                if let pill {
                    Capsule()
                        .fill(highlighted.wantsDarkPill
                              ? Color.black.opacity(0.18)
                              : highlighted.tint.opacity(0.18))
                        .frame(width: pill.width, height: pill.height)
                        .offset(x: pill.minX, y: pill.minY)
                }
            }
            .background(.bar, in: .capsule)
            .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
    }

    // MARK: - Shared

    /// The row itself, as wide as what is in it.
    ///
    /// It used to be a horizontal `ScrollView`, which takes the whole width
    /// whether it needs it or not — so four tabs sat in a bar sized for nine,
    /// adrift in their own capsule. The slot count is capped at what fits, so
    /// there is nothing left to scroll: an `HStack` hugs its contents and the
    /// capsule shrinks to them, centred.
    private func row<Item: View>(
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
        // Put a finger on the pill and slide. Nothing changes page until the
        // finger lifts: the drag moves a pill, and the page follows where it
        // was left — which is also why there is no tick at each crossing.
        // Ticking through six of them on the way to the sixth is a rattle.
        // One gesture for both, because two of them cannot share a short
        // distance. The items were buttons, and a drag to the tab *next door*
        // ends inside the neighbouring button's slop — so the tap won and put
        // the selection back where it started, while a drag two tabs over was
        // far enough to escape and worked. A tap is now simply a drag that went
        // nowhere, which is also what it is.
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                .onChanged { drag in
                    // Explicitly unanimated: an ancestor's implicit animation
                    // would otherwise interpolate every position, which is the
                    // pill chasing the finger rather than being held by it.
                    var instant = Transaction()
                    instant.disablesAnimations = true
                    withTransaction(instant) { dragX = drag.location.x }
                }
                .onEnded { drag in
                    let landed = tab(atX: drag.location.x) ?? selection

                    // Landing on the tab you are already on is not nothing:
                    // it means "take me back to the front of this one". It is
                    // written through like any other landing so that whoever
                    // owns the binding can act on it — the pill simply has
                    // nowhere to travel.
                    Feedback.control()
                    // Both in one transaction. Clearing the drag first puts the
                    // pill back on the old tab for a frame, so it travelled
                    // home and then out again — which is what it looked like.
                    withAnimation(Self.settle) {
                        selection = landed
                        dragX = nil
                    }
                }
        )
        // Springs to the item it was left on; follows exactly while held.
        .animation(dragX == nil ? Self.settle : nil, value: pill)
    }

    private func item(_ tab: RootView.Tab) -> some View {
        let isOn = tab == highlighted

        return Group {
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

                Text(tab.shortTitle)
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
            // Coloured by what the pill is over, not by what is selected, so
            // the colour arrives with the pill rather than after it.
            .foregroundStyle(isOn ? AnyShapeStyle(tab.activeTint) : AnyShapeStyle(.secondary))
            // Wide enough to read as a column, narrow enough that five of them
            // fit a phone without the row scrolling. Seventy was sized for a
            // bar that scrolled anyway; five fixed positions have to fit.
            .frame(minWidth: 56)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .contentShape(Capsule())
        }
        // The row handles the touching, so each item carries its own
        // accessibility instead — VoiceOver has no drag to make, and needs
        // something it can activate.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction {
            // Same as a tap: re-activating the current tab asks for its front
            // page, and is passed on rather than swallowed.
            Feedback.control()
            withAnimation(Self.settle) { selection = tab }
        }
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
