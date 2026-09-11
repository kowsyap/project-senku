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
    public enum Size { case small, medium }

    private let timer: RestTimer?
    private let size: Size
    private let now: Date

    public init(timer: RestTimer?, size: Size = .small, now: Date = .now) {
        self.timer = timer
        self.size = size
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

    /// The presets, as links. Widgets cannot hold state, so each is simply a
    /// way into the app with a duration already chosen.
    private var starter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("REST", systemImage: "timer")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            let presets: [RestPreset] = size == .medium
                ? RestPreset.allCases
                : [.sixtySeconds, .ninetySeconds, .twoMinutes]

            let columns = size == .medium ? 3 : 1
            let rows = stride(from: 0, to: presets.count, by: columns).map { start in
                Array(presets[start ..< min(start + columns, presets.count)])
            }

            VStack(spacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 6) {
                        ForEach(row) { tile($0) }
                        ForEach(0 ..< (columns - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tile(_ preset: RestPreset) -> some View {
        Link(destination: RestDeepLink.url(seconds: preset.duration)) {
            Text(preset.title)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary)
                )
        }
        .accessibilityLabel("Start a \(Display.spokenClock(preset.duration)) rest")
    }
}
