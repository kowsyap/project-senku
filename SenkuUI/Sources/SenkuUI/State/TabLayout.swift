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

    /// How many the middle of the bar holds.
    public static let slots = 3

    /// Everything that can go in a slot: the nine screens, less "Me" which is
    /// always first and "More" which is not a screen.
    public static var selectable: [RootView.Tab] {
        RootView.Tab.ordered.filter { $0 != .me }
    }

    private let defaults: UserDefaults

    public private(set) var chosen: [RootView.Tab]

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults

        let stored = (defaults.array(forKey: Self.storageKey) as? [String] ?? [])
            .compactMap(RootView.Tab.init(rawValue:))
            .filter { Self.selectable.contains($0) }

        self.chosen = stored.isEmpty ? Self.fallback : Array(stored.prefix(Self.slots))
    }

    /// What a fresh install gets: the timer you reach for mid-set, the session
    /// you are logging, and the water you are meant to be drinking all day.
    static let fallback: [RootView.Tab] = [.rest, .workout, .water]

    public func contains(_ tab: RootView.Tab) -> Bool { chosen.contains(tab) }

    public var isFull: Bool { chosen.count >= Self.slots }

    /// Adds or removes one, keeping the canonical order so the bar does not
    /// rearrange itself around the order you happened to tick things in.
    public func toggle(_ tab: RootView.Tab) {
        guard Self.selectable.contains(tab) else { return }

        if chosen.contains(tab) {
            // Never empty: a bar of "Me" and "More" is a menu with extra steps.
            guard chosen.count > 1 else { return }
            chosen.removeAll { $0 == tab }
        } else {
            guard !isFull else { return }
            chosen.append(tab)
            chosen = RootView.Tab.ordered.filter { chosen.contains($0) }
        }

        persist()
    }

    public func reset() {
        chosen = Self.fallback
        persist()
    }

    private func persist() {
        defaults.set(chosen.map(\.rawValue), forKey: Self.storageKey)
    }
}
#endif
