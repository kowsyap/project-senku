import WidgetKit
import SwiftUI
import SenkuCore
import SenkuUI

/// A watch face complication that starts a rest.
///
/// Configurable, so the interval on the face is the one you actually use: hold
/// the face, Edit, tap the complication, choose the minutes. Pressing it opens
/// Senku on the watch with that rest already running — a deep link rather than
/// an intent, so the app is the one process that owns the timer, the haptic and
/// the notification, exactly as on the phone.
///
/// A running rest is shown when the complication next refreshes, but the watch
/// decides when that is. The countdown on the face is therefore not a clock to
/// trust mid-set — the app is. This shows what a press would start.
struct RestComplication: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "SenkuWatchRest",
            intent: RestComplicationIntent.self,
            provider: RestComplicationProvider()
        ) { entry in
            RestComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(RestDeepLink.url(seconds: entry.seconds))
        }
        .configurationDisplayName("Start a rest")
        .description("One press starts a rest of the length you choose.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct RestComplicationEntry: TimelineEntry {
    let date: Date
    let minutes: Int

    var seconds: TimeInterval { TimeInterval(minutes * 60) }
}

struct RestComplicationProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RestComplicationEntry {
        RestComplicationEntry(date: .now, minutes: 2)
    }

    func snapshot(for configuration: RestComplicationIntent, in context: Context) async -> RestComplicationEntry {
        RestComplicationEntry(date: .now, minutes: Int(configuration.seconds / 60))
    }

    /// What the watch offers ready-made in the complication gallery.
    ///
    /// The same one, two and three minutes as the phone widget and the watch's
    /// own Rest screen, so the interval you pick on a face is one you already
    /// recognise. Anything else is a minute value away in Edit.
    ///
    /// Each description is a plain literal, and must stay one. WidgetKit
    /// refuses interpolated text here — `Text("\(minutes) min")` traps with
    /// "Formatted text for `AppIntentRecommendation` is not supported", which
    /// crashes the extension on launch and so removes *every* complication in
    /// this bundle from the gallery, with no visible error anywhere.
    func recommendations() -> [AppIntentRecommendation<RestComplicationIntent>] {
        [
            AppIntentRecommendation(intent: RestComplicationIntent(minutes: 1), description: Text("1 min rest")),
            AppIntentRecommendation(intent: RestComplicationIntent(minutes: 2), description: Text("2 min rest")),
            AppIntentRecommendation(intent: RestComplicationIntent(minutes: 3), description: Text("3 min rest")),
        ]
    }

    /// Nothing here changes on its own — the face shows what a press would
    /// start, which only changes when the configuration does. So one entry, and
    /// never a refresh, rather than a budget spent re-rendering a fixed number.
    func timeline(for configuration: RestComplicationIntent, in context: Context) async -> Timeline<RestComplicationEntry> {
        Timeline(
            entries: [RestComplicationEntry(date: .now, minutes: Int(configuration.seconds / 60))],
            policy: .never
        )
    }
}

struct RestComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RestComplicationEntry

    /// The colour this interval wears everywhere else in the app, when it is
    /// one of the three quick starts. Faces render most complications in the
    /// face's own tint, so this is a hint rather than a promise.
    private var tint: Color {
        RestPreset.quickStarts
            .first { Int($0.duration) == Int(entry.seconds) }?
            .tint ?? Senku.Palette.protein
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Rest \(entry.minutes) min")

        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 0) {
                    Text("START REST")
                        .font(.system(size: 10, weight: .heavy))
                        .opacity(0.75)
                    Text("\(entry.minutes) min")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                Spacer(minLength: 0)
            }

        default:
            VStack(spacing: -2) {
                Text("\(entry.minutes)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                Text("MIN")
                    .font(.system(size: 9, weight: .heavy))
                    .opacity(0.75)
            }
            .foregroundStyle(tint)
            .widgetAccentable()
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

