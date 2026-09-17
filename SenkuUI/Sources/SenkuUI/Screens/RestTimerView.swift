import SwiftUI
import SenkuCore
#if os(watchOS)
import WatchKit
#endif
#if os(iOS) && !targetEnvironment(macCatalyst)
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
        #if os(watchOS)
        RestRuntimeSession.shared.sync(with: timer, at: instant)
        #endif
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // The phone has a simpler answer than the watch: while a rest is
        // running, refuse to dim. Mid-set is the one time a screen locking
        // itself is purely a nuisance.
        UIApplication.shared.isIdleTimerDisabled = timer.isRunning && !timer.hasFinished(at: instant)
        #endif
        RestTimerStore.save(timer)

        // Mirrored to the other device unless this change *came* from it, which
        // would bounce straight back and, worse, restart its countdown.
        #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(watchOS)
        if !isAdopting {
            ProfileSync.shared.send(rest: timer.isIdle ? nil : timer)
        }
        #endif
    }

    /// True while applying a rest that arrived from the other device, so the
    /// mirror does not echo it back.
    @State private var isAdopting = false

    /// nil until asked. Whether an alert would reach the user when a rest ends
    /// with the app off screen — which is the only case that matters, because
    /// on screen the app rings the chime itself.
    @State private var canAlert: Bool?

    /// Tears the rest down across every surface that knows about it.
    private func endEverything() {
        timer.reset()
        RestTimerStore.clear()
        #if canImport(UserNotifications) && !os(macOS)
        RestNotifications.cancel()
        #endif
        #if os(iOS) && !targetEnvironment(macCatalyst)
        RestActivityController.shared.end(dismissing: .immediate)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
        #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(watchOS)
        ProfileSync.shared.send(rest: nil)
        #endif
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
        #if os(iOS) && !targetEnvironment(macCatalyst)
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
        .task {
            // A rest started on the other device shows here, and vice versa. It
            // carries an absolute deadline, so one that arrives late is still
            // counting down to the right instant.
            #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(watchOS)
            ProfileSync.shared.onRestReceived { incoming in
                isAdopting = true
                defer { isAdopting = false }

                timer = incoming ?? RestTimer(preset: RestPreset.matching(timer.duration) ?? .ninetySeconds)
                now = .now
                changed(at: now)
            }
            #endif

            // Asked up front rather than at the moment a rest is scheduled: a
            // permission prompt that appears as you start a set is a prompt
            // nobody reads, and dismissing it silently disables every alert.
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
                Feedback.restFinished()
                #if os(watchOS)
                // The haptic above only lands if the app is on screen. This one
                // reaches a wrist that is down, which is the case the rest timer
                // exists for.
                RestRuntimeSession.shared.alert()
                #endif
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

            #if os(watchOS)
            alertWarning
            holdIndicator
            watchControls

            Divider()
            watchQuickStarts

            Divider()
            watchCustom
            #else
            controls
            intervalPicker
            #endif
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

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

    /// Whether the watch is being kept awake for this rest.
    ///
    /// Only while one is running, and only as one small symbol: a filled bolt
    /// when the system granted an extended runtime session — the app stays in
    /// front, the screen stays on, and the wrist tap at the end is guaranteed —
    /// and a struck-through one when it refused, which is the state in which
    /// the rest ends quietly.
    @ViewBuilder
    private var holdIndicator: some View {
        if timer.isRunning, !isFinished {
            Label(
                RestRuntimeSession.shared.isHolding ? "Awake" : "Not held",
                systemImage: RestRuntimeSession.shared.isHolding ? "bolt.fill" : "bolt.slash.fill"
            )
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(
                RestRuntimeSession.shared.isHolding ? Senku.Palette.surplus : Senku.Palette.caution
            )
            .frame(maxWidth: .infinity)
        }
    }

    /// Three buttons on one line, icons only.
    ///
    /// A 40 mm screen has no room to spend on the word "Start" beside a play
    /// triangle that already says it, and mid-set you are aiming a finger at a
    /// shape rather than reading. The labels survive for VoiceOver.
    private var watchControls: some View {
        HStack(spacing: 8) {
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
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.bordered)
        .tint(tint)
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
        return max(40, (width - 2 * quickStartSpacing - 4) / 3)
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
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                        Text("MIN")
                            .font(.system(size: 11, weight: .heavy))
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

    /// Anything the three circles do not cover, in fifteen-second steps.
    private var watchCustom: some View {
        HStack {
            stepperButton("minus", by: -15)
            Text(Display.clock(timer.duration))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Rest interval")
                .accessibilityValue(Display.spokenClock(timer.duration))
            stepperButton("plus", by: 15)
        }
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
        Card("Rest interval", footnote: "Tapping an interval starts it straight away.") {
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
