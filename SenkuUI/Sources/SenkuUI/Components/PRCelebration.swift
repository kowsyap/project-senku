#if !os(watchOS)
import SwiftUI

/// A new personal record, celebrated: Goku powering up to Super Saiyan over
/// the logger, with the set that did it.
///
/// Eight drawn frames, base form to Super Saiyan, played once and then held on
/// the last — the transformation is the point, so it does not loop. About two
/// seconds in all; a tap ends it sooner. With Reduce Motion it is the last
/// frame alone, faded in.
struct PRCelebration: View {
    /// What was lifted, e.g. "100 kg × 5".
    let set: String
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame = 1
    @State private var isShowing = false
    @State private var textIsShowing = false
    @State private var isDone = false

    static let frames = 8
    /// The whole thing, before it fades.
    static let length: Duration = .seconds(2)

    var body: some View {
        ZStack {
            Color.black.opacity(isShowing ? 0.72 : 0)
                .ignoresSafeArea()

            VStack(spacing: 6) {
                Image("pr.saiyan.\(frame)", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 360)
                    .shadow(color: Senku.Palette.saiyan.opacity(0.6), radius: 24)

                Text("NEW PR")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1, green: 0.93, blue: 0.45), Senku.Palette.saiyan],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .orange.opacity(0.8), radius: 10)
                    .scaleEffect(textIsShowing ? 1 : 0.4)
                    .opacity(textIsShowing ? 1 : 0)

                Text(set)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .opacity(textIsShowing ? 1 : 0)
            }
            .opacity(isShowing ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New personal record, \(set)")
        .accessibilityAddTraits(.isButton)
        .task { await play() }
    }

    private func play() async {
        Feedback.success()

        if reduceMotion {
            frame = Self.frames
            withAnimation(.easeOut(duration: 0.25)) {
                isShowing = true
                textIsShowing = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.15)) { isShowing = true }
            // Base form to Super Saiyan in about a second, then the words.
            for next in 2...Self.frames {
                try? await Task.sleep(for: .milliseconds(130))
                guard !Task.isCancelled else { return }
                frame = next
            }
            withAnimation(.spring(duration: 0.35, bounce: 0.5)) { textIsShowing = true }
        }

        try? await Task.sleep(for: reduceMotion ? Self.length : Self.length - .milliseconds(910))
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

#Preview {
    PRCelebration(set: "100 kg × 5") {}
}
#endif
