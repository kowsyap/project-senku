import SwiftUI
import SenkuCore

/// The rest timer screen.
///
/// The view holds no countdown of its own. It keeps a `now` that a tick
/// advances and asks ``RestTimer`` what that instant means, which is why
/// backgrounding, locking and scrolling away all cost nothing: there is no
/// accumulated state here to fall behind.
///
/// The tick is deliberately idle unless there is something to redraw — a
/// paused or unstarted timer shows the same thing every frame.
public struct RestTimerView: View {
    @State private var timer: RestTimer
    @State private var now: Date

    /// 5 Hz. Fast enough that the ring moves smoothly and the seconds never
    /// look stuck, slow enough to be free.
    private let tick = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    /// `scrolls: false` drops the surrounding `ScrollView`. `ImageRenderer`
    /// has no window to size a scroll view against and renders one blank, so
    /// `senku-render` needs the bare content to review this screen offscreen.
    private let scrolls: Bool

    public init(
        timer: RestTimer = RestTimer(preset: .ninetySeconds),
        now: Date = .now,
        scrolls: Bool = true
    ) {
        _timer = State(initialValue: timer)
        _now = State(initialValue: now)
        self.scrolls = scrolls
    }

    /// Every control routes its mutation through here. The Live Activity is
    /// pushed from this single point rather than from each button, so a new
    /// control cannot quietly forget to keep the lock screen in step.
    private func changed(at instant: Date) {
        now = instant
        #if os(iOS) && !targetEnvironment(macCatalyst)
        RestActivityController.shared.sync(with: timer, at: instant)
        #endif
        #if canImport(UserNotifications) && !os(macOS)
        RestNotifications.sync(with: timer, at: instant)
        #endif
        RestTimerStore.save(timer)
    }

    private var remaining: TimeInterval { timer.remaining(at: now) }
    private var isFinished: Bool { timer.hasFinished(at: now) }

    public var body: some View {
        Group {
            if scrolls {
                ScrollView { content }
            } else {
                content
            }
        }
        .background(.background)
        .onAppear {
            // A rest started from Control Center, or one left running when iOS
            // reclaimed the app, is picked up here rather than silently lost.
            if timer.isIdle, let restored = RestTimerStore.load() {
                timer = restored
                now = .now
            }
        }
        .onReceive(tick) { instant in
            // A paused or unstarted timer renders identically every frame, so
            // there is nothing to gain from waking the view for it.
            guard timer.isRunning || timer.hasFinished(at: now) else { return }
            now = instant
            if timer.refresh(at: instant) {
                Feedback.restFinished()
                // The crossing is a state change, so the lock screen needs it;
                // the ticks either side of it do not.
                changed(at: instant)
            }
        }
    }

    private var content: some View {
        VStack(spacing: Senku.Metrics.stackSpacing) {
                TimerRing(
                    remaining: remaining,
                    progress: timer.progress(at: now),
                    overrun: timer.overrun(at: now),
                    isFinished: isFinished,
                    isPaused: timer.isPaused
                )
                .frame(maxWidth: Senku.Metrics.timerRingMaxWidth)
                .aspectRatio(1, contentMode: .fit)
                #if os(watchOS)
                .padding(.vertical, 2)
                #else
                .padding(.vertical, 8)
                #endif

            controls
            intervalPicker
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    Feedback.control()
                    if timer.isIdle {
                        #if canImport(UserNotifications) && !os(macOS)
                        RestNotifications.requestAuthorizationIfNeeded()
                        #endif
                    }
                    timer.toggle(at: .now)
                    changed(at: .now)
                } label: {
                    Label(primaryTitle, systemImage: primarySymbol)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    Feedback.control()
                    timer.reset()
                    changed(at: .now)
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(timer.isIdle)
                .accessibilityLabel("Reset")
            }

            Button {
                Feedback.control()
                timer.extend(by: 30, at: .now)
                changed(at: .now)
            } label: {
                Label(isFinished ? "Rest 30s more" : "Add 30 seconds", systemImage: "goforward.30")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var primaryTitle: String {
        if isFinished { return "Go again" }
        if timer.isPaused { return "Resume" }
        return timer.isRunning ? "Pause" : "Start"
    }

    private var primarySymbol: String {
        if isFinished { return "arrow.clockwise" }
        return timer.isRunning ? "pause.fill" : "play.fill"
    }

    // MARK: - Choosing the interval

    private var intervalPicker: some View {
        Card("Rest interval", footnote: "Tapping an interval starts it straight away.") {
            VStack(spacing: 12) {
                presetGrid

                Divider()

                HStack {
                    Text("Custom")
                        .font(.subheadline)
                    Spacer(minLength: 8)
                    stepperButton("minus", by: -15)
                    Text(Display.clock(timer.duration))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 54)
                        .accessibilityLabel("Rest interval")
                        .accessibilityValue(Display.spokenClock(timer.duration))
                    stepperButton("plus", by: 15)
                }
            }
        }
    }

    /// Deliberately not a `LazyVGrid`. Five fixed buttons gain nothing from
    /// laziness, and a lazy container does not build its offscreen children at
    /// all — which left the presets missing from the accessibility tree, and so
    /// unreachable by VoiceOver and by tests, until they were scrolled into
    /// view. An empty slot keeps the last row's buttons the same width as the
    /// rest rather than stretching to fill.
    private var presetGrid: some View {
        let columns = Senku.Metrics.presetColumns
        let rows = stride(from: 0, to: RestPreset.allCases.count, by: columns).map { start in
            Array(RestPreset.allCases[start ..< min(start + columns, RestPreset.allCases.count)])
        }

        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row) { presetButton($0) }
                    ForEach(0 ..< (columns - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
            }
        }
    }

    private func presetButton(_ preset: RestPreset) -> some View {
        let isSelected = timer.duration == preset.duration

        return Button {
            Feedback.control()
            let instant = Date.now
            try? timer.setDuration(preset.duration, at: instant)
            timer.start(at: instant)
            #if canImport(UserNotifications) && !os(macOS)
            RestNotifications.requestAuthorizationIfNeeded()
            #endif
            changed(at: instant)
        } label: {
            Text(preset.title)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? Senku.Palette.protein : nil)
        .accessibilityIdentifier("preset.\(preset.rawValue)")
        .accessibilityLabel("\(Display.spokenClock(preset.duration)). \(preset.detail)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Nudges the interval. While a rest is running this re-aims the deadline,
    /// so the number on screen is always the one actually being counted.
    private func stepperButton(_ symbol: String, by seconds: TimeInterval) -> some View {
        Button {
            Feedback.control()
            let instant = Date.now
            let target = timer.duration + seconds
            if (try? timer.setDuration(target, at: instant)) != nil {
                changed(at: instant)
            }
        } label: {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
        .disabled(!RestTimer.allowedDuration.contains(timer.duration + seconds))
        .accessibilityLabel(seconds > 0 ? "Longer" : "Shorter")
    }
}

#Preview("Idle") {
    RestTimerView()
}

#Preview("Running") {
    RestTimerView(
        timer: {
            var t = RestTimer(preset: .twoMinutes)
            t.start(at: .now)
            return t
        }()
    )
}
