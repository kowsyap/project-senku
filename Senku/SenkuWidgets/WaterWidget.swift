import WidgetKit
import SwiftUI
import SenkuCore
import SenkuUI

/// Water on the Home Screen, with buttons that work there.
///
/// The timeline is one entry that never expires on its own. Drinking is not
/// something a schedule can predict, so there is nothing for a refresh policy to
/// discover: the widget is reloaded by the thing that changes it — the button
/// in the widget, or the app when a drink is logged inside it.
struct WaterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SenkuWater", provider: WaterProvider()) { entry in
            WaterWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Water")
        .description("Today's total, and a tap to log a drink.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WaterEntry: TimelineEntry {
    let date: Date
    let summary: WaterSummary
}

struct WaterProvider: TimelineProvider {
    /// Read straight from the App Group, like every other widget here: a widget
    /// is a separate process and cannot see the app's own defaults.
    @MainActor
    private func current() -> WaterSummary {
        let store = WaterStore()
        return WaterSummary(store: store, profile: ProfileStore().profile, workouts: WorkoutStore())
    }

    func placeholder(in context: Context) -> WaterEntry {
        WaterEntry(date: .now, summary: WaterSummary(totalML: 1250, goalML: 2500))
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> Void) {
        Task { @MainActor in
            completion(WaterEntry(date: .now, summary: current()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry>) -> Void) {
        Task { @MainActor in
            // Midnight, and only midnight: the total resets then, and nothing
            // else about it is predictable.
            let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
            completion(
                Timeline(
                    entries: [WaterEntry(date: .now, summary: current())],
                    policy: .after(midnight)
                )
            )
        }
    }
}

struct WaterWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WaterEntry

    var body: some View {
        WaterWidgetView(
            summary: entry.summary,
            size: family == .systemMedium ? .medium : .small
        )
    }
}
