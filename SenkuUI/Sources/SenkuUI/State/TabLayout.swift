#if !os(watchOS)
import Foundation
import Observation

/// Which three screens sit in the bar beside "Me" and "More".
///
/// ## Why three and not nine
///
/// Nine tabs fitted only because the bar scrolled, and a bar that scrolls is a
/// bar you have to read before you can use it — the thing you want is somewhere
/// off the right-hand edge, and finding it costs a flick and a glance. Five
/// fixed positions can be hit without looking, which is the entire argument for
/// a tab bar over a menu.
///
/// So: "Me" first because it is the home screen, "More" last because it is the
/// way to everything else, and three in between that you choose. Somebody deep
/// in a cut wants water and food; somebody running a programme wants workout
/// and rest. Neither is wrong and the app should not have to guess.
@Observable
public final class TabLayout {
    static let storageKey = "senku.tabs.visible.v2"
    static let restKey = "senku.tabs.hidden.v1"

    /// How many the middle of the bar holds, before the bar has been measured.
    public static let defaultSlots = 3

    /// The widest a bar can be and still be worth another slot, per item.
    /// Fifty-six is the minimum an item is allowed to be, plus its padding.
    static let itemWidth: CGFloat = 64

    /// How many middle slots a screen of this width can carry.
    ///
    /// Four on a Max-sized phone — six tabs in all — and three on everything
    /// else. Measured from the screen rather than from the bar as it is drawn,
    /// because the bar now hugs its contents: asking a thing that shrinks to
    /// fit how much room it has is a circle.
    ///
    /// | Screen | Tabs |
    /// | --- | --- |
    /// | 440 pt (16/17 Pro Max) | 6 |
    /// | 430 pt (14/15 Pro Max) | 6 |
    /// | 402, 393, 390, 375 pt | 5 |
    ///
    /// The two-slot floor is for a narrow window on iPad, where a bar of one
    /// thing and More would be a menu with extra steps.
    public static func slots(forScreenWidth width: CGFloat) -> Int {
        let usable = width - 24 - 12     // the bar's margins, then the row's
        let fits = Int((usable + 4) / (itemWidth + 4))
        return min(4, max(2, fits - 2))  // less Me and More
    }

    /// Everything that can go in a slot: the nine screens, less "Me" which is
    /// always first and "More" which is not a screen.
    public static var selectable: [RootView.Tab] {
        RootView.Tab.ordered.filter { $0 != .me }
    }

    private let defaults: UserDefaults

    public private(set) var chosen: [RootView.Tab]

    /// Everything else, in the order it appears under More. Kept rather than
    /// derived, because that order is also yours to set.
    public private(set) var others: [RootView.Tab]

    /// How many the bar can carry, once it knows how wide it is.
    public private(set) var slots: Int = TabLayout.defaultSlots

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults

        let stored = (defaults.array(forKey: Self.storageKey) as? [String] ?? [])
            .compactMap(RootView.Tab.init(rawValue:))
            .filter { Self.selectable.contains($0) }

        // Not trimmed here. The bar has not been measured yet, so trimming now
        // would cut a fourth tab against a default of three and never put it
        // back — `fit(screenWidth:)` does the trimming once the width is known.
        let inBar = stored.isEmpty ? Self.fallback : stored
        self.chosen = inBar

        let storedRest = (defaults.array(forKey: Self.restKey) as? [String] ?? [])
            .compactMap(RootView.Tab.init(rawValue:))
            .filter { Self.selectable.contains($0) && !inBar.contains($0) }

        // Anything neither list mentions — a screen added in a later version —
        // joins the end of More rather than vanishing.
        let missing = Self.selectable.filter { !inBar.contains($0) && !storedRest.contains($0) }
        self.others = storedRest + missing
    }

    /// Told by the window, once its width is known.
    ///
    /// Growing the bar does not fill the new slot — that is a choice, and the
    /// app should not make it on your behalf. Shrinking it does drop the tail,
    /// because the alternative is a tab you cannot see.
    public func fit(screenWidth: CGFloat) {
        slots = Self.slots(forScreenWidth: screenWidth)

        // Not guarded on the count having changed: a bar measured at three
        // slots starts at three, so "no change" is exactly the case where a
        // stored fourth tab is sitting off the end of it.
        guard chosen.count > slots else { return }

        // Pushed to the front of More rather than dropped: it was your fourth
        // choice on a wider screen, and it is the likeliest thing you are
        // reaching for on this one.
        let overflow = chosen.suffix(from: slots)
        chosen = Array(chosen.prefix(slots))
        others.insert(contentsOf: overflow, at: 0)
        persist()
    }

    /// What a fresh install gets: the timer you reach for mid-set, the session
    /// you are logging, and the water you are meant to be drinking all day.
    static let fallback: [RootView.Tab] = [.rest, .workout, .water]

    public func contains(_ tab: RootView.Tab) -> Bool { chosen.contains(tab) }

    public var isFull: Bool { chosen.count >= slots }

    /// Moves one between the bar and More.
    ///
    /// Added at the end of wherever it lands rather than sorted back into a
    /// canonical order — the order is yours now, and re-sorting would undo a
    /// rearrangement every time something was ticked.
    public func toggle(_ tab: RootView.Tab) {
        guard Self.selectable.contains(tab) else { return }

        if chosen.contains(tab) {
            // Never empty: a bar of "Me" and "More" is a menu with extra steps.
            guard chosen.count > 1 else { return }
            chosen.removeAll { $0 == tab }
            others.insert(tab, at: 0)
        } else {
            guard !isFull else { return }
            others.removeAll { $0 == tab }
            chosen.append(tab)
        }

        persist()
    }

    /// Drag-to-reorder, within the bar.
    public func moveInBar(from offsets: IndexSet, to destination: Int) {
        chosen.move(fromOffsets: offsets, toOffset: destination)
        persist()
    }

    /// Drag-to-reorder, within More.
    public func moveInMore(from offsets: IndexSet, to destination: Int) {
        others.move(fromOffsets: offsets, toOffset: destination)
        persist()
    }

    public func reset() {
        chosen = Array(Self.fallback.prefix(slots))
        others = Self.selectable.filter { !chosen.contains($0) }
        persist()
    }

    private func persist() {
        defaults.set(chosen.map(\.rawValue), forKey: Self.storageKey)
        defaults.set(others.map(\.rawValue), forKey: Self.restKey)
    }
}
#endif
