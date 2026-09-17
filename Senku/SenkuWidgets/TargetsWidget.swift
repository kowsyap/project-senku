import WidgetKit
import SwiftUI
import SenkuCore
import SenkuUI

/// Today's targets on the Home Screen.
///
/// A widget cannot run a timer, so this is the other half of Senku that is
/// worth a glance: the numbers you are eating to. It reads the saved profile
/// out of the shared App Group container — a widget is a separate process and
/// cannot see the app's own `UserDefaults`.
///
/// The timeline is a single entry with `.never` refresh. The plan is a pure
/// function of a profile that only changes when the user edits it, so there is
/// nothing for a schedule to discover; the app reloads timelines on save
/// instead.
struct TargetsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SenkuTargets", provider: TargetsProvider()) { entry in
            TargetsWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily targets")
        .description("Your calories and macros for the day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TargetsEntry: TimelineEntry {
    let date: Date
    let profile: ProfileStore.Profile?
}

struct TargetsProvider: TimelineProvider {
    private func current() -> ProfileStore.Profile? {
        ProfileStore().profile
    }

    func placeholder(in context: Context) -> TargetsEntry {
        TargetsEntry(date: .now, profile: current())
    }

    func getSnapshot(in context: Context, completion: @escaping (TargetsEntry) -> Void) {
        completion(TargetsEntry(date: .now, profile: current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TargetsEntry>) -> Void) {
        completion(Timeline(entries: [TargetsEntry(date: .now, profile: current())], policy: .never))
    }
}

/// Bridges WidgetKit's environment to the package's plain view.
struct TargetsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TargetsEntry

    var body: some View {
        TargetsView(
            profile: entry.profile,
            size: family == .systemMedium ? .medium : .small
        )
    }
}
