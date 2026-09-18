import WidgetKit
import SwiftUI
import SenkuCore
import SenkuUI

/// The scale on the Home Screen.
///
/// Tapping it opens the weigh-in sheet rather than the app's last screen —
/// `senku://weigh-in`, handled in `RootView` — because a widget that only shows
/// a number you already know is a widget with nothing to do.
struct WeightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SenkuWeight", provider: WeightProvider()) { entry in
            WeightWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "senku://weigh-in"))
        }
        .configurationDisplayName("Weight")
        .description("Your last reading and the trend. Tap to log one.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WeightWidgetEntry: TimelineEntry {
    let date: Date
    let summary: WeightSummary
}

struct WeightProvider: TimelineProvider {
    @MainActor
    private func current() -> WeightSummary {
        WeightSummary(log: WeightLogStore(), profile: ProfileStore().profile)
    }

    func placeholder(in context: Context) -> WeightWidgetEntry {
        WeightWidgetEntry(
            date: .now,
            summary: WeightSummary(lastWeightKG: 82.5, lastLoggedAt: .now, trendKG: 82.9)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeightWidgetEntry) -> Void) {
        Task { @MainActor in
            completion(WeightWidgetEntry(date: .now, summary: current()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeightWidgetEntry>) -> Void) {
        Task { @MainActor in
            // A weigh-in happens when it happens; the app reloads this on save.
            completion(
                Timeline(entries: [WeightWidgetEntry(date: .now, summary: current())], policy: .never)
            )
        }
    }
}

struct WeightWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeightWidgetEntry

    var body: some View {
        WeightWidgetView(
            summary: entry.summary,
            size: family == .systemMedium ? .medium : .small
        )
    }
}
