import WidgetKit
import SwiftUI
import SenkuCore
import SenkuUI

/// Today's protein and calories on the Home Screen.
///
/// Read-only, unlike the water widget beside it — see `FoodWidgetView` for why
/// a button here would have to guess at a number this feature exists to keep
/// honest. Tapping opens the food screen, where a meal can be said properly.
struct FoodWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SenkuFood", provider: FoodProvider()) { entry in
            FoodWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "senku://food"))
        }
        .configurationDisplayName("Food")
        .description("Protein and calories against today's targets.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FoodEntry: TimelineEntry {
    let date: Date
    let summary: IntakeSummary
}

struct FoodProvider: TimelineProvider {
    /// Straight from the App Group: a widget is its own process and cannot see
    /// the app's defaults.
    @MainActor
    private func current() -> IntakeSummary {
        IntakeSummary(store: IntakeStore(), profile: ProfileStore().profile)
    }

    func placeholder(in context: Context) -> FoodEntry {
        FoodEntry(
            date: .now,
            summary: IntakeSummary(
                proteinG: 96,
                proteinTargetG: 180,
                calories: 1740,
                calorieTarget: 2500,
                hasTargets: true
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FoodEntry) -> Void) {
        Task { @MainActor in
            completion(FoodEntry(date: .now, summary: current()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FoodEntry>) -> Void) {
        Task { @MainActor in
            // Midnight and nothing else. Eating is not on a schedule a timeline
            // can predict; the app reloads this whenever a meal is logged.
            let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
            completion(
                Timeline(
                    entries: [FoodEntry(date: .now, summary: current())],
                    policy: .after(midnight)
                )
            )
        }
    }
}

struct FoodWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FoodEntry

    var body: some View {
        FoodWidgetView(
            summary: entry.summary,
            size: family == .systemMedium ? .medium : .small
        )
    }
}
