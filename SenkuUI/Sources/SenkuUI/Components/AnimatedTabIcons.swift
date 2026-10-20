#if os(iOS)
import SwiftUI

/// A tab's icon in the bar, moving while it is the tab you are on.
///
/// Each tab has its own small loop — Goku powering up, a curl, a running
/// timer — and every one of them stands still on a tab you are not on, and
/// when Reduce Motion is on. Most are the tab's own SF Symbol, moved or cut
/// apart in code, so they keep the symbol's size, weight and tint; the curl
/// and the aura are drawn frames.
struct TabIcon: View {
    let tab: RootView.Tab
    /// Selected: the one the loops play for.
    let isActive: Bool
    /// Under the pill, which may be ahead of the selection while dragging.
    let isOn: Bool

    private var weight: Font.Weight { isOn ? .semibold : .regular }

    var body: some View {
        switch tab {
        case .me:
            if let mark = tab.mark { goku(mark) } else { symbol }
        case .workout:
            CurlIcon(isActive: isActive)
                .frame(height: 21)
        case .food:
            CutleryIcon(isActive: isActive)
                .fontWeight(weight)
                .frame(height: 21)
        case .water:
            SplashDrop(isActive: isActive, weight: weight)
        case .rest:
            RunningTimer(isActive: isActive)
                .fontWeight(weight)
                .frame(height: 21)
        case .weight:
            symbol.modifier(StepOn(isActive: isActive))
        case .quickCalc, .records:
            symbol.modifier(Wiggle(isActive: isActive))
        case .dueDates:
            PageFlip(isActive: isActive) { symbol }
        case .anime:
            MovieGlow(isActive: isActive, weight: weight)
        default:
            symbol
        }
    }

    private var symbol: some View {
        Image(systemName: tab.symbol)
            .font(.system(size: 18, weight: weight))
            .frame(height: 21)
    }

    /// "Me" wears a face rather than the system's anonymous silhouette — it
    /// is the one tab that is about a particular person. A template, so it
    /// takes the row's colour like every other icon here: grey while it
    /// waits its turn, gold only when it is the tab you are on.
    private func goku(_ mark: String) -> some View {
        Image(mark, bundle: .module)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: 21)
            // Before the aura, so he moves and it holds still.
            .modifier(PoweringUp(isActive: isActive))
            // An aura flickering behind him, wider than his slot.
            .background {
                AuraIcon(isActive: isActive)
                    .frame(width: 38, height: 38)
                    .offset(y: -2)
                    .allowsHitTesting(false)
            }
    }
}

/// The Workout tab's figure, doing curls — a man with dumbbells or a woman
/// with a barbell, after the profile's sex, as the body maps are.
///
/// Nine frames of one rep, played on a loop while the tab is selected and
/// left on the first — arms down — when it is not, or when Reduce Motion is
/// on. Template images, so it takes the bar's grey or the tab's colour like
/// every other icon here.
struct CurlIcon: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.senkuBodySex) private var sex

    static let frameCount = 9
    /// Seconds per frame: about one and a third seconds a rep.
    static let frameDuration = 0.15

    var body: some View {
        let animates = isActive && !reduceMotion

        TimelineView(.animation(minimumInterval: Self.frameDuration, paused: !animates)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / Self.frameDuration)
            let frame = animates ? tick % Self.frameCount + 1 : 1

            Image("workout.curl.\(sex == .female ? "female" : "male").\(frame)", bundle: .module)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        }
    }
}

/// The Food tab's fork and knife, crossing into an X and parting again.
///
/// The system's `fork.knife`, drawn twice and cut at the gap between the two,
/// so each half can turn on its own: the same symbol as everywhere else, at the
/// same size, when it is still. The figures below are measured from the
/// symbol's own bounds — where the gap is, and the middle of each handle.
struct CutleryIcon: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the tab was last switched to, so it starts apart rather than
    /// wherever the clock happens to be.
    @State private var start = Date.now

    nonisolated static let split = 0.577
    nonisolated static let forkX = 0.245
    nonisolated static let knifeX = 0.878
    nonisolated static let meet = (forkX + knifeX) / 2
    static let angle = 28.0
    /// Crossing, held, parting, held: 0.6 s each.
    static let period = 2.4

    var body: some View {
        let animates = isActive && !reduceMotion

        TimelineView(.animation(paused: !animates)) { context in
            let t = animates ? Self.crossing(at: context.date.timeIntervalSince(start)) : 0

            ZStack {
                half(fork: true)
                    .rotationEffect(.degrees(Self.angle * t), anchor: UnitPoint(x: Self.forkX, y: 0.55))
                    .visualEffect { content, proxy in
                        content.offset(x: (Self.meet - Self.forkX) * proxy.size.width * t)
                    }
                half(fork: false)
                    .rotationEffect(.degrees(-Self.angle * t), anchor: UnitPoint(x: Self.knifeX, y: 0.55))
                    .visualEffect { content, proxy in
                        content.offset(x: (Self.meet - Self.knifeX) * proxy.size.width * t)
                    }
            }
        }
        .onChange(of: isActive) { _, active in
            if active { start = .now }
        }
    }

    /// 0 apart, 1 crossed, eased at both ends of each move.
    static func crossing(at elapsed: TimeInterval) -> Double {
        let quarter = period / 4
        let phase = elapsed.truncatingRemainder(dividingBy: period)
        func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }

        switch phase {
        case ..<quarter: return ease(phase / quarter)
        case ..<(quarter * 2): return 1
        case ..<(quarter * 3): return 1 - ease((phase - quarter * 2) / quarter)
        default: return 0
        }
    }

    private func half(fork: Bool) -> some View {
        Image(systemName: "fork.knife")
            .resizable()
            .scaledToFit()
            .mask {
                GeometryReader { proxy in
                    Rectangle()
                        .frame(width: proxy.size.width * (fork ? Self.split : 1 - Self.split))
                        .frame(maxWidth: .infinity, alignment: fork ? .leading : .trailing)
                }
            }
    }
}

/// The Water tab's drop, splashing: it falls into place from a little above,
/// squashes as it lands and springs back, and four droplets fly out in arcs
/// over a spreading ripple. Then a rest, and again.
struct SplashDrop: View {
    let isActive: Bool
    let weight: Font.Weight

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the tab was last switched to, so it starts with a fall.
    @State private var start = Date.now

    /// Fall, splash and the rest after it.
    static let period = 1.3
    /// A moment after everything has settled: the drop, still.
    static let still = 1.0

    var body: some View {
        let animates = isActive && !reduceMotion

        TimelineView(.animation(paused: !animates)) { context in
            let t = animates
                ? context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: Self.period)
                : Self.still
            SplashScene(t: t, weight: weight)
        }
        .onChange(of: isActive) { _, active in
            if active { start = .now }
        }
    }
}

/// One moment of the splash, `t` seconds into the loop.
private struct SplashScene: View {
    let t: Double
    let weight: Font.Weight

    static let fall = 0.32
    static let flight = 0.45
    static let drops: [(vx: Double, vy: Double)] = [(-40, 46), (-22, 64), (22, 64), (40, 46)]
    static let gravity = 260.0

    var body: some View {
        let impact = t - Self.fall
        // Falling: from 9 pt above, accelerating, stretched thin.
        let fallProgress = min(1, t / Self.fall)
        let lift = t < Self.fall ? -9 * (1 - fallProgress * fallProgress) : 0
        let stretch: Double = {
            if t < Self.fall { return 0.12 * fallProgress }
            let u = impact / 0.35
            guard u < 1 else { return 0 }
            return -0.28 * exp(-4 * u) * cos(2 * .pi * 1.5 * u)
        }()

        Image(systemName: "drop.fill")
            .font(.system(size: 18, weight: weight))
            .scaleEffect(x: 1 - stretch * 0.7, y: 1 + stretch, anchor: .bottom)
            .offset(y: lift)
            .opacity(t < Self.fall ? min(1, t / 0.12) : 1)
            .frame(height: 21)
            .overlay(alignment: .bottom) {
                if impact > 0 && impact < Self.flight {
                    let fade = 1 - impact / Self.flight
                    ZStack {
                        Ellipse()
                            .stroke(lineWidth: 1)
                            .frame(width: 8 + 22 * impact / Self.flight, height: 2 + 3 * impact / Self.flight)
                            .opacity(fade * 0.8)
                        ForEach(0 ..< Self.drops.count, id: \.self) { i in
                            let d = Self.drops[i]
                            Circle()
                                .frame(width: 3.2, height: 3.2)
                                .offset(
                                    x: d.vx * impact + (d.vx < 0 ? -3 : 3),
                                    y: -(d.vy * impact - 0.5 * Self.gravity * impact * impact) - 2
                                )
                                .opacity(fade)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

/// The aura behind Goku on the Me tab: nine frames of a flickering ki field,
/// played on a loop while the tab is selected. Nothing at all when it is not,
/// or when Reduce Motion is on — he is only powered up while you are there.
struct AuraIcon: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let frameCount = 9
    static let frameDuration = 0.08

    var body: some View {
        if isActive && !reduceMotion {
            TimelineView(.animation(minimumInterval: Self.frameDuration)) { context in
                let tick = Int(context.date.timeIntervalSinceReferenceDate / Self.frameDuration)

                Image("goku.aura.\(tick % Self.frameCount + 1)", bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            }
            .transition(.opacity)
        }
    }
}

/// Goku charging: a slow float — up about a point and back every 1.6 seconds
/// — with a faint, fast tremble on top. Offsets only, so the slot does not
/// move and the aura behind him holds still.
struct PoweringUp: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let animates = isActive && !reduceMotion

        TimelineView(.animation(paused: !animates)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let lift = animates ? -1.2 * (0.5 - 0.5 * cos(2 * .pi * t / 1.6)) : 0
            // Two sines at unrelated rates read as a shake rather than a
            // wobble; small enough to be a hum, not a rattle.
            let jitterX = animates ? 0.45 * sin(t * 47) * sin(t * 13) : 0
            let jitterY = animates ? 0.35 * sin(t * 53 + 1) : 0

            content.offset(x: jitterX, y: lift + jitterY)
        }
    }
}

/// The Rest tab's timer, its hand sweeping round like a timer running: one
/// turn every two seconds, from where the symbol draws it.
///
/// The system's `timer` with its own hand cut out — a disc taken from the
/// middle, the button at the top put back — and a hand of the same shape
/// drawn over it, turning on the ring's centre. Measured from the symbol's
/// own bounds.
struct RunningTimer: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the tab was last switched to, so the hand starts where it rests.
    @State private var start = Date.now

    nonisolated static let centre = 0.496
    /// Where the symbol's hand points, in degrees from twelve o'clock.
    static let restAngle = -42.6
    static let secondsPerTurn = 2.0

    var body: some View {
        let animates = isActive && !reduceMotion

        TimelineView(.animation(paused: !animates)) { context in
            let turn = animates
                ? context.date.timeIntervalSince(start) / Self.secondsPerTurn * 360
                : 0

            ZStack {
                Image(systemName: "timer")
                    .resizable()
                    .scaledToFit()
                    .mask {
                        GeometryReader { proxy in
                            let w = proxy.size.width
                            ZStack {
                                Rectangle()
                                Circle()
                                    .frame(width: 0.76 * w, height: 0.76 * w)
                                    .position(x: Self.centre * w, y: Self.centre * w)
                                    .blendMode(.destinationOut)
                                // The button at the top, which the disc
                                // would otherwise take a bite out of.
                                Rectangle()
                                    .frame(width: 0.16 * w, height: 0.30 * w)
                                    .position(x: 0.5 * w, y: 0.15 * w)
                            }
                            .compositingGroup()
                        }
                    }

                TimerHand()
                    .rotation(
                        .degrees(Self.restAngle + turn),
                        anchor: UnitPoint(x: Self.centre, y: Self.centre)
                    )
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .onChange(of: isActive) { _, active in
            if active { start = .now }
        }
    }
}

/// The timer's hand, pointing at twelve: a round base on the pivot, tapering
/// to a round tip.
private struct TimerHand: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let pivot = CGPoint(x: RunningTimer.centre * w, y: RunningTimer.centre * w)
        let base = 0.068 * w, tipRadius = 0.025 * w
        let tip = CGPoint(x: pivot.x, y: pivot.y - 0.31 * w)

        var path = Path()
        path.addArc(center: pivot, radius: base, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: tip.x - tipRadius, y: tip.y))
        path.addArc(center: tip, radius: tipRadius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// A quick wiggle — a few swings either side, dying away — then a rest, and
/// again. For icons with nothing of their own to act out.
struct Wiggle: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    static let period = 1.5
    static let swing = 0.6

    func body(content: Content) -> some View {
        let animates = isActive && !reduceMotion

        TimelineView(.animation(paused: !animates)) { context in
            let t = context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: Self.period)
            let angle = animates && t < Self.swing
                ? 12 * sin(2 * .pi * 5 * t) * (1 - t / Self.swing)
                : 0

            content.rotationEffect(.degrees(angle))
        }
        .onChange(of: isActive) { _, active in
            if active { start = .now }
        }
    }
}

/// The Weight tab's scale, stepped on: pressed down from its base, springing
/// back past where it started and settling, then a rest, and again. Wider as
/// it squashes, so it reads as weight landing rather than the icon shrinking.
struct StepOn: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    static let period = 1.4
    static let press = 0.15
    static let settle = 0.6
    static let depth = 0.2

    func body(content: Content) -> some View {
        let animates = isActive && !reduceMotion

        TimelineView(.animation(paused: !animates)) { context in
            let t = context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: Self.period)
            let squash = animates ? Self.squash(at: t) : 0

            content.scaleEffect(x: 1 - squash * 0.6, y: 1 + squash, anchor: .bottom)
        }
        .onChange(of: isActive) { _, active in
            if active { start = .now }
        }
    }

    /// Negative while pressed down, briefly positive as it springs past rest.
    static func squash(at t: TimeInterval) -> Double {
        if t < press {
            let x = t / press
            return -depth * x * x * (3 - 2 * x)
        }
        let u = (t - press) / settle
        guard u < 1 else { return 0 }
        return -depth * exp(-5 * u) * cos(2 * .pi * 2 * u)
    }
}

/// The Dues tab's calendar, its top page lifting away and over like a page
/// turned, then again: a copy of the symbol folding back on its top edge
/// and fading, over the one underneath.
struct PageFlip<Content: View>: View {
    let isActive: Bool
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    static var period: Double { 1.4 }
    static var flip: Double { 0.55 }

    var body: some View {
        let animates = isActive && !reduceMotion

        TimelineView(.animation(paused: !animates)) { context in
            let t = context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: Self.period)
            let progress = min(1, t / Self.flip)
            let eased = progress * progress * (3 - 2 * progress)

            ZStack {
                content
                if animates && progress < 1 {
                    content
                        .rotation3DEffect(
                            .degrees(-110 * eased),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .top,
                            perspective: 0.6
                        )
                        .opacity(1 - eased)
                }
            }
        }
        .onChange(of: isActive) { _, active in
            if active { start = .now }
        }
    }
}

/// The Anime tab's television lighting up and dimming like a screen showing
/// a film: the filled symbol faded in over the outline, in a slow swell with
/// a flicker on top.
struct MovieGlow: View {
    let isActive: Bool
    let weight: Font.Weight

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let animates = isActive && !reduceMotion

        TimelineView(.animation(paused: !animates)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let glow = animates
                ? min(1, max(0, 0.5 + 0.5 * sin(2 * .pi * t / 1.4) + 0.15 * sin(t * 19)))
                : 0

            ZStack {
                Image(systemName: "sparkles.tv")
                Image(systemName: "sparkles.tv.fill")
                    .opacity(glow)
            }
            .font(.system(size: 18, weight: weight))
            .frame(height: 21)
        }
    }
}
#endif
