#if os(watchOS)
import SwiftUI
import SenkuCore

/// Water, on a watch: a bottle, what is left, and three buttons.
///
/// Everything else about water lives on the phone — the goal's arithmetic, the
/// history, the reminders, the streak. What a wrist is for is the one action:
/// you have just drunk something, and it takes one tap to say so.
///
/// The total shown is the phone's, plus anything logged here that the phone has
/// not confirmed yet. Waiting for the round trip would leave the bottle
/// unchanged for as long as the phone is asleep, which is most of the time —
/// and a button that appears to do nothing gets pressed twice.
public struct WatchWaterView: View {
    private let summary: WaterSummary
    private let pendingML: Double
    private let onDrink: (Double) -> Void

    public init(summary: WaterSummary, pendingML: Double, onDrink: @escaping (Double) -> Void) {
        self.summary = summary
        self.pendingML = pendingML
        self.onDrink = onDrink
    }

    private var totalML: Double { summary.totalML + pendingML }
    private var goalML: Double { max(1, summary.goalML) }
    private var fraction: Double { min(1, totalML / goalML) }
    private var remainingML: Double { max(0, goalML - totalML) }

    public var body: some View {
        GeometryReader { proxy in
            // A bottle is taller than it is wide, but not by four times: given
            // the whole height it drew as a column with a rounded top. Sized
            // from its own width instead, and centred against the figures.
            // The same width *and* height as the buttons opposite, so the two
            // columns are one block rather than two shapes that happen to be
            // side by side. Both figures are derived from the button metrics
            // below rather than guessed, so changing a button size moves the
            // bottle with it.
            let columnWidth = proxy.size.width * 0.42
            let stackHeight = Self.buttonHeight * 3 + Self.buttonSpacing * 2

            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    bottle
                        .frame(width: columnWidth, height: stackHeight)

                    // Stacked, so each button is a full-width target rather than
                    // a third of one: three side by side on a 40 mm case gives
                    // each about a fingertip's width, which is the wrong size
                    // for the one thing this page exists to do.
                    buttons
                        .frame(width: columnWidth)
                }

                // The whole width, under both columns: the total is the one
                // thing here you read rather than press, and tucked under the
                // bottle it was the smallest thing on the screen.
                figures
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.horizontal, 8)
    }

    private var bottle: some View {
        GeometryReader { proxy in
            let shape = RoundedRectangle(cornerRadius: proxy.size.width * 0.3, style: .continuous)

            ZStack(alignment: .bottom) {
                shape.fill(.quaternary.opacity(0.4))

                Rectangle()
                    .fill(fraction >= 1 ? Senku.Palette.surplus : Senku.Palette.deficit)
                    .frame(height: proxy.size.height * fraction)
                    .animation(.snappy(duration: 0.3), value: fraction)

                shape.strokeBorder(.quaternary, lineWidth: 1.5)

                // Inside the bottle, because that is where the eye already is
                // — and white on the fill, plain on the empty part, so it stays
                // readable as the water rises past it.
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(fraction > 0.55 ? Color.white : Color.secondary)
                    .frame(maxHeight: .infinity)
            }
            .clipShape(shape)
        }
        .accessibilityHidden(true)
    }

    private var figures: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                // The phone's tab icon, so the page says what it is without a
                // title. Beside the number rather than above it: the watch has
                // no room for a line that carries nothing but identity, and
                // this way it costs no height at all.
                Image(systemName: "drop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Senku.Palette.deficit)

                Text("\(Int(totalML))")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(fraction >= 1 ? Senku.Palette.surplus : Senku.Palette.deficit)
            }

            Text(remainingML > 0 ? "\(Int(remainingML)) ml left" : "target met")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water")
        .accessibilityValue("\(Int(totalML)) of \(Int(goalML)) millilitres")
    }

    /// The phone's three containers, in the phone's sizes.
    static let buttonHeight: CGFloat = 34
    static let buttonSpacing: CGFloat = 5

    private var buttons: some View {
        VStack(spacing: Self.buttonSpacing) {
            ForEach(Array(summary.containers.prefix(3).enumerated()), id: \.offset) { _, size in
                Button {
                    Feedback.control()
                    onDrink(size)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(size))")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("ml")
                            .font(.system(size: 10, weight: .semibold))
                            .opacity(0.7)
                    }
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: Self.buttonHeight)
                    .background(Senku.Palette.deficit.opacity(0.22), in: .rect(cornerRadius: 9))
                    .foregroundStyle(Senku.Palette.deficit)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log \(Int(size)) millilitres")
            }
        }
    }
}
#endif
