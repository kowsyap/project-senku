import WidgetKit
import SwiftUI
import SenkuCore
import SenkuUI

/// The rest timer on the Home Screen.
///
/// The timeline is short and explicit rather than `.never`: a running rest has
/// a known end, so the widget schedules one entry for the moment it finishes
/// and then goes quiet. Nothing polls, and nothing has to guess.
struct RestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SenkuRest", provider: RestProvider()) { entry in
            RestWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Rest timer")
        .description("Start a rest, and see the one you are on.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RestEntry: TimelineEntry {
    let date: Date
    let timer: RestTimer?
}

struct RestProvider: TimelineProvider {
    func placeholder(in context: Context) -> RestEntry {
        RestEntry(date: .now, timer: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RestEntry) -> Void) {
        completion(RestEntry(date: .now, timer: RestTimerStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RestEntry>) -> Void) {
        let timer = RestTimerStore.load()
        let entry = RestEntry(date: .now, timer: timer)

        // Redraw once when the rest ends, so the countdown is replaced by the
        // start buttons rather than sitting at zero.
        if let endsAt = timer?.endsAt, endsAt > .now {
            completion(Timeline(entries: [entry], policy: .after(endsAt)))
        } else {
            completion(Timeline(entries: [entry], policy: .never))
        }
    }
}

/// Bridges WidgetKit's environment to the package's plain view.
struct RestWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RestEntry

    var body: some View {
        RestWidgetView(
            timer: entry.timer,
            size: family == .systemMedium ? .medium : .small,
            now: entry.date
        )
    }
}
