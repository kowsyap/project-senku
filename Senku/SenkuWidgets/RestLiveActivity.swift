import ActivityKit
import WidgetKit
import SwiftUI
import SenkuCore
import SenkuUI

/// The rest timer on the lock screen and in the Dynamic Island.
///
/// Nothing here is driven by the app. The content state carries the whole
/// `RestTimer`, which carries an absolute deadline, so `Text(timerInterval:)`
/// and `ProgressView(timerInterval:)` animate the countdown by themselves. The
/// app pushes only when the timer's *state* changes — which is why this keeps
/// running correctly with Senku suspended.
struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            LockScreenView(timer: context.state.timer)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.45))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let timer = context.state.timer

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(timer: timer)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(timer.tint)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressBar(timer: timer)
                        RestActivityControls()
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(timer.tint)
            } compactTrailing: {
                CountdownText(timer: timer)
                    .monospacedDigit()
                    .foregroundStyle(timer.tint)
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(timer.tint)
            }
        }
    }
}

// MARK: - Pieces

/// Hands the countdown to the system where it can run one, and falls back to a
/// static figure where it cannot — paused and finished timers have no deadline
/// to count towards.
private struct CountdownText: View {
    let timer: RestTimer

    var body: some View {
        if let endsAt = timer.endsAt {
            Text(timerInterval: endsAt.addingTimeInterval(-timer.duration)...endsAt,
                 countsDown: true)
                .multilineTextAlignment(.trailing)
        } else if timer.isPaused {
            Text(Display.clock(timer.remaining(at: .now)))
        } else {
            Text("Done")
        }
    }
}

private struct ProgressBar: View {
    let timer: RestTimer

    var body: some View {
        if let endsAt = timer.endsAt {
            ProgressView(
                timerInterval: endsAt.addingTimeInterval(-timer.duration)...endsAt,
                countsDown: true
            ) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(timer.tint)
        } else {
            ProgressView(value: timer.isPaused ? timer.progress(at: .now) : 1)
                .progressViewStyle(.linear)
                .tint(timer.tint)
        }
    }
}

/// End and extend, from outside the app.
///
/// These exist because iOS never tells an app it was force quit: a rest whose
/// app has been swiped away keeps running, with the system holding both the
/// notification and this activity. Without a control out here there is no way
/// to stop it except reopening the app — which is exactly what someone who just
/// closed it does not want to do.
private struct RestActivityControls: View {
    var body: some View {
        HStack(spacing: 8) {
            Button(intent: ExtendRestIntent()) {
                Label("+30s", systemImage: "goforward.30")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .tint(Senku.Palette.protein)

            Button(intent: StopRestIntent()) {
                Label("End", systemImage: "xmark")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .tint(.secondary)
        }
        .buttonStyle(.bordered)
    }
}

private struct LockScreenView: View {
    let timer: RestTimer

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timer.headline)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                CountdownText(timer: timer)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(timer.tint)

                ProgressBar(timer: timer)
                    .padding(.top, 4)

                RestActivityControls()
                    .padding(.top, 6)
            }

            Spacer(minLength: 0)

            Image(systemName: timer.isPaused ? "pause.circle.fill" : "timer")
                .font(.system(size: 34))
                .foregroundStyle(timer.tint)
        }
    }
}

// MARK: - Shared presentation

private extension RestTimer {
    /// Matches `TimerRing`: green once done, amber over the last ten seconds.
    var tint: Color {
        if hasFinished(at: .now) { return Senku.Palette.surplus }
        if remaining(at: .now) <= 10 { return Senku.Palette.caution }
        return Senku.Palette.protein
    }

    var headline: String {
        if hasFinished(at: .now) { return "Rest done" }
        return isPaused ? "Rest paused" : "Resting"
    }
}
