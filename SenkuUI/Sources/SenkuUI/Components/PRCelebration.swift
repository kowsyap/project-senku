#if !os(watchOS)
import SwiftUI
import ImageIO

/// Which animation a new personal record plays, chosen in the workout's
/// settings.
///
/// The frames are HEIC files in the iPhone app's bundle, not this package's
/// assets: everything that links the package — both widgets and the watch —
/// carries a copy of its assets, and only the app plays this. Plain files
/// rather than an asset catalog, because the catalog re-encodes HEIC
/// losslessly and gives back the size HEIC saved.
enum PRAnimation: String, CaseIterable, Identifiable {
    case saiyan
    case arise
    case domain
    /// The words alone.
    case plain

    static let storageKey = "senku.prAnimation.v1"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saiyan: "Super Saiyan"
        case .arise: "Arise"
        case .domain: "Domain Expansion"
        case .plain: "None"
        }
    }

    var frameCount: Int {
        switch self {
        case .saiyan: 8
        case .arise, .domain: 9
        case .plain: 0
        }
    }

    /// The glow behind the figure, and the bottom of the words' gradient.
    var glow: Color {
        switch self {
        case .saiyan, .plain: Senku.Palette.saiyan
        case .arise: Color(red: 0.58, green: 0.32, blue: 0.98)
        case .domain: Color(red: 0.42, green: 0.40, blue: 1)
        }
    }

    /// The top of the words' gradient.
    var highlight: Color {
        switch self {
        case .saiyan, .plain: Color(red: 1, green: 0.93, blue: 0.45)
        case .arise: Color(red: 0.88, green: 0.80, blue: 1)
        case .domain: Color(red: 0.80, green: 0.90, blue: 1)
        }
    }

    /// The frames, decoded, in order; empty for `.plain` or if any is missing.
    func loadFrames() -> [CGImage] {
        let frames = (0..<frameCount).compactMap { index -> CGImage? in
            guard let url = Bundle.main.url(forResource: "pr.\(rawValue).\(index + 1)", withExtension: "heic"),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil)
            else { return nil }
            // Decoded now, not on first draw, so the first frames do not stutter.
            return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        }
        return frames.count == frameCount ? frames : []
    }
}

/// A new personal record, celebrated: the chosen figure powering up over the
/// logger, with the set that did it.
///
/// The frames play once and then hold on the last — the transformation is the
/// point, so it does not loop. About two seconds in all; a tap ends it sooner.
/// With Reduce Motion it is the last frame alone, faded in.
struct PRCelebration: View {
    /// What was lifted, e.g. "100 kg × 5"; nil for a preview.
    let set: String?
    /// Nil plays the one chosen in settings.
    var animation: PRAnimation? = nil
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(PRAnimation.storageKey, store: SenkuStorage.shared) private var chosen: PRAnimation = .saiyan
    @State private var frames: [CGImage] = []
    @State private var frame = 0
    @State private var isShowing = false
    @State private var textIsShowing = false
    @State private var isDone = false

    /// The whole thing, before it fades.
    static let length: Duration = .seconds(2)
    private static let beat: Duration = .milliseconds(130)

    private var playing: PRAnimation { animation ?? chosen }

    var body: some View {
        ZStack {
            Color.black.opacity(isShowing ? 0.72 : 0)
                .ignoresSafeArea()

            VStack(spacing: 6) {
                if frames.indices.contains(frame) {
                    Image(decorative: frames[frame], scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 360)
                        .shadow(color: playing.glow.opacity(0.6), radius: 24)
                }

                Text("NEW PR")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [playing.highlight, playing.glow],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: playing.glow.opacity(0.8), radius: 10)
                    .scaleEffect(textIsShowing ? 1 : 0.4)
                    .opacity(textIsShowing ? 1 : 0)

                if let set {
                    Text(set)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .opacity(textIsShowing ? 1 : 0)
                }
            }
            .padding(.horizontal, 16)
            .opacity(isShowing ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(set.map { "New personal record, \($0)" } ?? "New personal record")
        .accessibilityAddTraits(.isButton)
        .task { await play() }
    }

    private func play() async {
        frames = playing.loadFrames()
        Feedback.success()

        let played: Duration
        if reduceMotion || frames.count < 2 {
            frame = max(frames.count - 1, 0)
            played = .zero
            withAnimation(.easeOut(duration: 0.25)) {
                isShowing = true
                textIsShowing = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.15)) { isShowing = true }
            // First frame to last in about a second, then the words.
            for next in 1..<frames.count {
                try? await Task.sleep(for: Self.beat)
                guard !Task.isCancelled else { return }
                frame = next
            }
            played = Self.beat * (frames.count - 1)
            withAnimation(.spring(duration: 0.35, bounce: 0.5)) { textIsShowing = true }
        }

        try? await Task.sleep(for: Self.length - played)
        guard !Task.isCancelled else { return }
        finish()
    }

    private func finish() {
        guard !isDone else { return }
        isDone = true
        withAnimation(.easeIn(duration: 0.2)) { isShowing = false }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            onFinish()
        }
    }
}

/// The workout settings' choice of PR animation, with a way to see it.
struct PRAnimationSection: View {
    @AppStorage(PRAnimation.storageKey, store: SenkuStorage.shared) private var chosen: PRAnimation = .saiyan
    @State private var previewing: PRAnimation?

    var body: some View {
        Section {
            Picker("Animation", selection: $chosen) {
                ForEach(PRAnimation.allCases) { animation in
                    Text(animation.title).tag(animation)
                }
            }
            Button("Preview") { previewing = chosen }
        } header: {
            Text("New PR")
        }
        #if os(iOS)
        .fullScreenCover(item: $previewing) { animation in
            PRCelebration(set: nil, animation: animation) {
                var quiet = Transaction()
                quiet.disablesAnimations = true
                withTransaction(quiet) { previewing = nil }
            }
            .presentationBackground(.clear)
        }
        #else
        .overlay {
            if let previewing {
                PRCelebration(set: nil, animation: previewing) { self.previewing = nil }
            }
        }
        #endif
    }
}

#Preview {
    PRCelebration(set: "100 kg × 5") {}
}
#endif
