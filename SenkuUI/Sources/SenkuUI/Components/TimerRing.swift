import SwiftUI
import SenkuCore

/// The countdown dial: a ring that empties as the rest runs out, wrapped
/// around the time remaining.
///
/// The ring is drawn from `remaining` rather than elapsed, so the filled arc is
/// always literally "how much rest is left" — the thing being read at a glance
/// from arm's length, mid-set.
public struct TimerRing: View {
    private let remaining: TimeInterval
    private let progress: Double
    private let overrun: TimeInterval
    private let isFinished: Bool
    private let isPaused: Bool
    private let lineWidth: CGFloat

    public init(
        remaining: TimeInterval,
        progress: Double,
        overrun: TimeInterval = 0,
        isFinished: Bool = false,
        isPaused: Bool = false,
        lineWidth: CGFloat = Senku.Metrics.ringWidth
    ) {
        self.remaining = remaining
        self.progress = progress
        self.overrun = overrun
        self.isFinished = isFinished
        self.isPaused = isPaused
        self.lineWidth = lineWidth
    }

    /// Green once it is done — the "go" signal. Amber over the last ten
    /// seconds, as a warning to get back under the bar. Blue otherwise.
    private var tint: Color {
        if isFinished { return Senku.Palette.surplus }
        if remaining <= 10 { return Senku.Palette.caution }
        return Senku.Palette.protein
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0, 1 - progress))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: progress)

            VStack(spacing: 2) {
                Text(Display.clock(remaining))
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(tint)

                if isFinished {
                    Text(overrun >= 1 ? Display.overrun(overrun) : "Done")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else if isPaused {
                    Text("Paused")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(lineWidth + 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("rest.remaining")
        .accessibilityLabel("Rest remaining")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        if isFinished { return "Rest finished" }
        let spoken = Display.spokenClock(remaining)
        return isPaused ? "\(spoken), paused" : spoken
    }
}
