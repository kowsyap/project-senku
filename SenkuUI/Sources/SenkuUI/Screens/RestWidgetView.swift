import SwiftUI
import SenkuCore

/// The Home Screen widget's face.
///
/// A widget cannot run code on a schedule fine enough to tick, but it does not
/// need to: a running rest has an absolute deadline, and `Text(timerInterval:)`
/// counts down against it on its own. When there is no rest to show — including
/// every build without the App Group, where the widget genuinely cannot see the
/// app's state — it falls back to being what it is most useful as anyway: a
/// one-tap start.
public struct RestWidgetView: View {
    /// The three intervals worth a one-tap start, in the order they are stacked.
    ///
    /// One, two and three minutes — accessory work, moderate compounds, heavy
    /// compounds. The colours run red, orange, yellow down that list, so the
    /// right button is found by colour at arm's length rather than by reading
    /// three near-identical numbers mid-set.
    public static let presets: [(preset: RestPreset, tint: Color)] = [
        (.sixtySeconds, .red),
        (.twoMinutes, .orange),
        (.threeMinutes, .yellow),
    ]

    private let timer: RestTimer?
    private let now: Date

    public init(timer: RestTimer?, now: Date = .now) {
        self.timer = timer
        self.now = now
    }

    /// Only a running rest is worth showing. A finished or paused one is a
    /// stale-looking number on a Home Screen the widget cannot refresh.
    private var running: RestTimer? {
        guard let timer, timer.isRunning, !timer.hasFinished(at: now) else { return nil }
        return timer
    }

    public var body: some View {
        if let running, let endsAt = running.endsAt {
            countdown(running, endsAt: endsAt)
        } else {
            starter
        }
    }

    private func countdown(_ timer: RestTimer, endsAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("RESTING", systemImage: "timer")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(timerInterval: endsAt.addingTimeInterval(-timer.duration)...endsAt, countsDown: true)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(Senku.Palette.protein)

            Spacer(minLength: 2)

            ProgressView(
                timerInterval: endsAt.addingTimeInterval(-timer.duration)...endsAt,
                countsDown: true
            ) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.linear)
                .tint(Senku.Palette.protein)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The presets, one per row.
    private var starter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("REST", systemImage: "timer")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(Self.presets, id: \.preset) { preset, tint in
                    tile(preset, tint: tint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A tap starts the rest where it belongs.
    ///
    /// On iOS that is a `LiveActivityIntent`, which iOS runs in the app's own
    /// process in the background: the rest starts, the Dynamic Island picks it
    /// up, and the app is never brought forward. Everywhere else — and on any
    /// system without the intent — the deep link opens the app and does the
    /// same work there.
    @ViewBuilder
    private func tile(_ preset: RestPreset, tint: Color) -> some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 17.0, *) {
            Button(intent: StartRestFromWidgetIntent(seconds: preset.duration)) {
                face(preset, tint: tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start a \(Display.spokenClock(preset.duration)) rest")
        } else {
            link(preset, tint: tint)
        }
        #else
        link(preset, tint: tint)
        #endif
    }

    private func link(_ preset: RestPreset, tint: Color) -> some View {
        Link(destination: RestDeepLink.url(seconds: preset.duration)) {
            face(preset, tint: tint)
        }
        .accessibilityLabel("Start a \(Display.spokenClock(preset.duration)) rest")
    }

    private func face(_ preset: RestPreset, tint: Color) -> some View {
        Text(preset.title)
            .font(.callout.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.22))
            )
    }
}
