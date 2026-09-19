import SwiftUI
import SenkuCore
// The tick below is a Combine publisher. SwiftUI re-exports enough of Combine
// for `Timer.publish` to compile without this, but not enough to name its type
// in a stored property — which is what four warnings on one line were saying.
import Combine
#if os(watchOS)
import WatchKit
#endif
#if os(iOS)
import UIKit
#endif

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
    @Environment(\.scenePhase) private var scenePhase

    @State private var timer: RestTimer
    @State private var now: Date

    /// 5 Hz. Fast enough that the ring moves smoothly and the seconds never
    /// look stuck, slow enough to be free.
    ///
    /// Only the *running* screen needs that rate. Past the deadline the display
    /// is a count of whole seconds since the rest ended, so redrawing five
    /// times a second would be four wasted passes out of five — see the tick
    /// handler, which throttles itself rather than juggling two publishers.
    private let tick = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    /// How long a finished rest is allowed to keep counting up before the app
    /// gives up on it.
    ///
    /// The count-up is useful — it answers "how long have I been standing
    /// here?" — but only for a few minutes. Past that you have left, and a
    /// timer that counts into the small hours is a Live Activity sitting on
    /// your lock screen and a screen refreshing for nobody.
    private static let overrunLimit: TimeInterval = 10 * 60

    public init(
        timer: RestTimer = RestTimer(preset: .ninetySeconds),
        now: Date = .now
    ) {
        _timer = State(initialValue: timer)
        _now = State(initialValue: now)
    }

    /// Every control routes its mutation through here. The Live Activity is
    /// pushed from this single point rather than from each button, so a new
    /// control cannot quietly forget to keep the lock screen in step.
    private func changed(at instant: Date) {
        now = instant
        #if os(iOS)
        RestActivityController.shared.sync(with: timer, at: instant)
        // The chime, booked on the audio clock so it still sounds with the
        // phone locked and silenced.
        RestChime.sync(with: timer, at: instant)
        #endif
        #if canImport(UserNotifications) && !os(macOS)
        RestNotifications.sync(with: timer, at: instant)
        #endif
        #if os(watchOS)
        RestRuntimeSession.shared.sync(with: timer, at: instant)
        #endif
        #if os(iOS)
        // The phone has a simpler answer than the watch: while a rest is
        // running, refuse to dim. Mid-set is the one time a screen locking
        // itself is purely a nuisance.
        UIApplication.shared.isIdleTimerDisabled = timer.isRunning && !timer.hasFinished(at: instant)
        #endif
        RestTimerStore.save(timer)
    }

    /// nil until asked. Whether an alert would reach the user when a rest ends
    /// with the app off screen — which is the only case that matters, because
    /// on screen the app rings the chime itself.
    @State private var canAlert: Bool?

    /// False while this screen is mounted but not on display — see
    /// `senkuScreenIsVisible`. On the watch, and in a sheet, it is always true.
    #if os(iOS)
    @Environment(\.senkuScreenIsVisible) private var isVisible
    #else
    private let isVisible = true
    #endif

    /// Tears the rest down across every surface that knows about it.
    private func endEverything() {
        timer.reset()
        RestTimerStore.clear()
        #if canImport(UserNotifications) && !os(macOS)
        RestNotifications.cancel()
        #endif
        #if os(iOS)
        RestActivityController.shared.end(dismissing: .immediate)
        RestChime.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
    }

    private var remaining: TimeInterval { timer.remaining(at: now) }
    private var isFinished: Bool { timer.hasFinished(at: now) }

    public var body: some View {
        Group {
            #if os(watchOS)
            // No scroll view. The ring, the three controls and the three
            // intervals are the whole screen, and a timer whose start buttons
            // are below the fold is a timer you fight with mid-set.
            content
            #else
            ScrollView { content }
            #endif
        }
        .background(.background)
        .onReceive(NotificationCenter.default.publisher(for: RestDeepLink.didStart)) { _ in
            // A widget tap while this screen is already on display.
            if let started = RestTimerStore.load() {
                timer = started
                now = .now
            }
        }
        .onAppear {
            // A rest started from Control Center, or one left running when iOS
            // reclaimed the app, is picked up here rather than silently lost.
            //
            // A *finished* one is not. It is restored only while it is still
            // running or freshly done: coming back tomorrow to a timer sitting
            // at zero, announcing a set you finished last night, is worse than
            // coming back to a clean screen.
            if timer.isIdle, let restored = RestTimerStore.load(), restored.isWorthRestoring() {
                timer = restored
                now = .now
            } else if timer.isIdle {
                RestTimerStore.clear()
            }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            // Swiping the app out of the app switcher is a deliberate act, and
            // "stop what you are doing" is the only sensible reading of it. So
            // the rest ends with the app: the stored timer goes, the Live
            // Activity is dismissed, the alert is cancelled and the watch is
            // told.
            //
            // iOS does not always deliver this — a force quit of an already
            // suspended app gets no callback at all — which is why the restore
            // above also refuses anything stale.
            endEverything()
        }
        #endif
        // Keyed on visibility, not on appearing: every page of the shell stays
        // mounted, so an unkeyed task ran while this screen was hidden and the
        // app asked for notification permission at launch, from a screen nobody
        // had opened.
        .task(id: isVisible) {
            guard isVisible else { return }

            // Asked as the screen opens rather than at the moment a rest is
            // scheduled: a permission prompt that appears as you start a set is
            // a prompt nobody reads, and dismissing it silently disables every
            // alert.
            #if canImport(UserNotifications) && !os(macOS)
            if await RestNotifications.canAlert() {
                canAlert = true
            } else {
                canAlert = await RestNotifications.requestAuthorization()
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            // The alert has done its job the moment you are looking at the app.
            // Leaving it in Notification Center afterwards is pure litter — you
            // already know the rest ended, and it stays there until swiped.
            guard phase == .active else { return }
            #if canImport(UserNotifications) && !os(macOS)
            if !timer.isRunning { RestNotifications.clearDelivered() }
            #endif
        }
        .onReceive(tick) { instant in
            // A paused or unstarted timer renders identically every frame, so
            // there is nothing to gain from waking the view for it.
            guard timer.isRunning || timer.hasFinished(at: now) else { return }

            if timer.hasFinished(at: instant) {
                // Long over. Stop counting, and take the Live Activity and the
                // pending alert down with it.
                guard timer.overrun(at: instant) < Self.overrunLimit else {
                    endEverything()
                    return
                }
                // One redraw a second is all a count of seconds can show.
                guard Int(instant.timeIntervalSinceReferenceDate)
                    != Int(now.timeIntervalSinceReferenceDate)
                else { return }
            }

            now = instant
            if timer.refresh(at: instant) {
                // Two very different things reach this line. One is a rest
                // ending while you are watching it. The other is the app
                // waking up to a rest that ended while it was suspended, and
                // noticing only now — the crossing is detected on the first
                // tick after the app comes back, however long after the fact
                // that is.
                //
                // Only the first is worth making a noise about. Firing the
                // chime and the haptics for the second means reopening Senku
                // ten minutes later announces a rest you finished, walked away
                // from, and already know about. The state still has to be
                // brought up to date either way, which is what `changed` does
                // below; it is the alert that is conditional.
                if timer.overrun(at: instant) < 3 {
                    #if !os(watchOS)
                    Feedback.restFinished()
                    #endif

                    #if canImport(UserNotifications) && !os(macOS) && !os(watchOS)
                    // Sweep the notification the app has just made redundant.
                    //
                    // `changed` below cancels it too, but it loses a race it
                    // cannot win: the crossing is noticed a moment *before* the
                    // trigger fires, so the cancel lands first and the system
                    // then delivers anyway. The delivered copy sits there
                    // silently while the app is in front — and reappears with
                    // its own haptic the instant the app leaves, which on the
                    // watch is fifteen seconds later when the runtime session
                    // winds down. That is the mystery alert a quarter of a
                    // minute after a rest you have already been told about.
                    Task {
                        // Inside the grace period above, so the notification is
                        // cancelled before it is ever delivered: with the app on
                        // screen the chime has already said it, and the alert
                        // would be the same news twice.
                        try? await Task.sleep(for: .seconds(2))
                        RestNotifications.cancel()
                    }
                    #endif
                }
                // The crossing is a state change, so the lock screen needs it;
                // the ticks either side of it do not.
                changed(at: instant)
            }
        }
    }

    #if os(watchOS)
    /// The watch screen, measured rather than guessed.
    ///
    /// The ring used to be `.frame(maxWidth:)` plus `aspectRatio(.fit)`, which
    /// in a column resolves the square against whichever of the two proposals
    /// is smaller — the *height* the stack was willing to hand it, not the
    /// width of the case. That is how a 148pt ring drew at about 55. Here the
    /// diameter is worked out from the space that is actually left once the
    /// controls, the divider and the three intervals have taken theirs, so the
    /// ring is as big as the case allows and the column ends at the bottom
    /// edge instead of leaving a black band under the buttons.
    private var content: some View {
        GeometryReader { proxy in
            let diameter = ringDiameter(in: proxy.size)

            VStack(spacing: watchSpacing) {
                TimerRing(
                    remaining: remaining,
                    progress: timer.progress(at: now),
                    overrun: timer.overrun(at: now),
                    isFinished: isFinished,
                    isPaused: timer.isPaused,
                    deadline: timer.endsAt
                )
                .frame(width: diameter, height: diameter)
                .padding(.bottom, ringGap)

                alertWarning
                watchControls

                Divider()
                watchQuickStarts
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.horizontal)
    }

    /// Height taken by everything under the ring, so the ring can have the rest.
    ///
    /// Every term here is a number this file also draws with, rather than an
    /// estimate of one. `.bordered` was the reason an earlier budget came up
    /// short and the ring grew over the buttons: the style adds its own
    /// padding around the glyph, so a 26pt image became a control nearly 50pt
    /// tall and nothing in the arithmetic knew. The controls are drawn plain
    /// now, at exactly ``controlHeight``.
    private func ringDiameter(in size: CGSize) -> CGFloat {
        let divider: CGFloat = 1
        let spacing: CGFloat = watchSpacing * 3
        let alert: CGFloat = canAlert == false ? 34 : 0
        // The ring is a circle in a square: at the bottom of that square the
        // stroke is at its widest, so a gap that would be generous beside text
        // reads as touching here. The gap itself is the whole allowance now —
        // the extra cushion that was here as well was simply diameter the
        // countdown could have had.
        let slack: CGFloat = ringGap

        let below = controlHeight + divider + spacing + alert + quickStartDiameter + slack
        return max(88, min(size.width, size.height - below))
    }

    private var watchSpacing: CGFloat { 4 }

    /// Air between the countdown and the controls.
    private var ringGap: CGFloat { 10 }

    /// Small enough to leave the ring the screen, tall enough to hit mid-set.
    private var controlHeight: CGFloat { 30 }
    #else
    private var content: some View {
        let stackSpacing = Senku.Metrics.stackSpacing

        return VStack(spacing: stackSpacing) {
                TimerRing(
                    remaining: remaining,
                    progress: timer.progress(at: now),
                    overrun: timer.overrun(at: now),
                    isFinished: isFinished,
                    isPaused: timer.isPaused,
                    deadline: timer.endsAt
                )
                .frame(maxWidth: Senku.Metrics.timerRingMaxWidth)
                .aspectRatio(1, contentMode: .fit)
                .padding(.vertical, 8)

            controls
            intervalPicker
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
    #endif

    // MARK: - Controls, watch

    #if os(watchOS)
    /// Says so only when an alert would *not* reach you. Confirming that
    /// something works is a line of clutter on a 40 mm screen; the case worth
    /// interrupting for is the one where the timer cannot tell you.
    @ViewBuilder
    private var alertWarning: some View {
        if canAlert == false {
            Button {
                Task {
                    canAlert = await RestNotifications.requestAuthorization()
                    if canAlert == true { RestNotifications.sync(with: timer) }
                }
            } label: {
                Label("Alerts off — tap", systemImage: "bell.slash.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Senku.Palette.caution)
            .accessibilityHint("Senku cannot tell you when a rest ends unless notifications are allowed")
        }
    }

    /// Three buttons on one line, icons only.
    ///
    /// A 40 mm screen has no room to spend on the word "Start" beside a play
    /// triangle that already says it, and mid-set you are aiming a finger at a
    /// shape rather than reading. The labels survive for VoiceOver.
    private var watchControls: some View {
        HStack(spacing: 6) {
            watchControl(primarySymbol, label: primaryTitle, tint: Senku.Palette.protein) {
                timer.toggle(at: .now)
                changed(at: .now)
            }

            watchControl("arrow.counterclockwise", label: "Reset", tint: nil) {
                timer.reset()
                changed(at: .now)
            }
            .disabled(timer.isIdle)

            watchControl("goforward.30", label: isFinished ? "Rest 30 seconds more" : "Add 30 seconds", tint: nil) {
                timer.extend(by: 30, at: .now)
                changed(at: .now)
            }
        }
    }

    private func watchControl(
        _ symbol: String,
        label: String,
        tint: Color?,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Feedback.control()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint ?? .primary)
                .frame(width: 46, height: controlHeight)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((tint ?? .gray).opacity(tint == nil ? 0.24 : 0.22))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// One, two and three minutes as circles, in the colours the Home Screen
    /// widget uses for the same intervals.
    ///
    /// The diameter is measured from the case rather than left to the layout.
    /// `aspectRatio` inside a `VStack` resolves against whichever of width and
    /// height is smaller, and in a scrolling column that is the height — which
    /// is why the circles came out small with the row's width unused. Three
    /// across the screen, minus the gaps, is the number actually wanted.
    private var quickStartDiameter: CGFloat {
        let width = WKInterfaceDevice.current().screenBounds.width
        return min(42, max(34, (width - 2 * quickStartSpacing - 30) / 3))
    }

    private var quickStartSpacing: CGFloat { 6 }

    private var watchQuickStarts: some View {
        HStack(spacing: quickStartSpacing) {
            ForEach(RestPreset.quickStarts) { preset in
                let tint = preset.tint
                Button {
                    Feedback.control()
                    let instant = Date.now
                    try? timer.setDuration(preset.duration, at: instant)
                    timer.start(at: instant)
                    changed(at: instant)
                } label: {
                    VStack(spacing: -2) {
                        Text("\(preset.minutes)")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                        Text("MIN")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.5)
                            .opacity(0.75)
                    }
                    .foregroundStyle(tint)
                    .frame(width: quickStartDiameter, height: quickStartDiameter)
                    .background(Circle().fill(tint.opacity(0.22)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("preset.\(preset.rawValue)")
                .accessibilityLabel("\(Display.spokenClock(preset.duration)). \(preset.detail)")
                .accessibilityAddTraits(timer.duration == preset.duration ? [.isSelected] : [])
            }
        }
        // The screen's side padding is right for text and wasteful for three
        // circles that should be as big as the case allows.
        .padding(.horizontal, -12)
    }

    #endif

    // MARK: - Controls, phone and Mac

    #if !os(watchOS)
    /// Three controls on one line, as on the watch.
    ///
    /// They were stacked — a wide primary button with reset beside it, and
    /// "Add 30 seconds" on its own row underneath — which gave the least used
    /// of the three the most room. One row of equals reads faster mid-set and
    /// matches what your wrist already shows.
    private var controls: some View {
        HStack(spacing: 10) {
            restControl(primarySymbol, label: primaryTitle, tint: Senku.Palette.protein) {
                timer.toggle(at: .now)
                changed(at: .now)
            }

            restControl("arrow.counterclockwise", label: "Reset", tint: nil) {
                timer.reset()
                changed(at: .now)
            }
            .disabled(timer.isIdle)

            restControl("goforward.30", label: isFinished ? "+30s" : "+30s", tint: nil) {
                timer.extend(by: 30, at: .now)
                changed(at: .now)
            }
        }
    }

    private func restControl(
        _ symbol: String,
        label: String,
        tint: Color?,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Feedback.control()
            action()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .accessibilityLabel(label == "+30s" ? "Add 30 seconds" : label)
    }

    #endif

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

    #if !os(watchOS)
    private var intervalPicker: some View {
        Card("Rest interval") {
            VStack(spacing: 12) {
                presetRow

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

    /// The four intervals on one line, each in its own colour.
    ///
    /// Deliberately not a `LazyVGrid`: four fixed buttons gain nothing from
    /// laziness, and a lazy container does not build its offscreen children at
    /// all — which left the presets missing from the accessibility tree, and so
    /// unreachable by VoiceOver and by tests, until they were scrolled into
    /// view.
    private var presetRow: some View {
        HStack(spacing: 8) {
            ForEach(RestPreset.oneTapStarts) { presetButton($0) }
        }
    }

    private func presetButton(_ preset: RestPreset) -> some View {
        let isSelected = timer.duration == preset.duration

        return Button {
            Feedback.control()
            let instant = Date.now
            try? timer.setDuration(preset.duration, at: instant)
            timer.start(at: instant)
            changed(at: instant)
        } label: {
            VStack(spacing: -1) {
                Text("\(preset.minutes)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("MIN")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.5)
                    .opacity(0.75)
            }
            .foregroundStyle(preset.tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(preset.tint.opacity(isSelected ? 0.35 : 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(preset.tint.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("preset.\(preset.rawValue)")
        .accessibilityLabel("\(Display.spokenClock(preset.duration)). \(preset.detail)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    #endif

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
