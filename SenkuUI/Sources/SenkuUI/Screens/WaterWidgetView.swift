#if os(iOS)
import SwiftUI
import SenkuCore
#if canImport(AppIntents)
import AppIntents
#endif

/// Water on the Home Screen: how much today, and one tap to add more.
///
/// The watch page's shape, at a widget's size — a bottle, the total, and the
/// containers as buttons. The buttons are the point: a widget you can only read
/// is a worse version of opening the app, while a widget you can press is the
/// fastest way there is to log a glass.
public struct WaterWidgetView: View {
    public enum Size { case small, medium }

    private let summary: WaterSummary
    private let size: Size

    public init(summary: WaterSummary, size: Size) {
        self.summary = summary
        self.size = size
    }

    private var fraction: Double { summary.fraction }
    private var tint: Color { fraction >= 1 ? Senku.Palette.surplus : Senku.Palette.deficit }

    public var body: some View {
        // The watch page's layout at both sizes: the bottle beside the
        // containers, the total under both. One shape for one feature — the
        // small widget used to be a progress bar and a single button, which
        // meant the two sizes taught you different things about the same
        // screen.
        VStack(spacing: size == .medium ? 8 : 6) {
            HStack(alignment: .top, spacing: size == .medium ? 12 : 8) {
                bottle
                    .frame(width: columnWidth, height: stackHeight)

                buttons
                    .frame(width: columnWidth)
            }

            header
        }
        .frame(maxWidth: .infinity)
    }

    /// Both columns the same width, and the bottle the height of the buttons
    /// beside it — derived from the button metrics rather than guessed, so the
    /// two stay aligned if a size changes.
    private var buttonHeight: CGFloat { size == .medium ? 30 : 24 }
    private var buttonSpacing: CGFloat { size == .medium ? 6 : 4 }
    private var stackHeight: CGFloat { buttonHeight * 3 + buttonSpacing * 2 }
    private var columnWidth: CGFloat { size == .medium ? 66 : 56 }

    private var buttons: some View {
        VStack(spacing: buttonSpacing) {
            ForEach(Array(summary.containers.prefix(3).enumerated()), id: \.offset) { _, millilitres in
                logButton(Int(millilitres))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(tint)
                Text("\(Int(summary.totalML).formatted())")
                    .font(.system(size: size == .medium ? 28 : 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(tint)
            }

            Text(summary.remainingML > 0
                 ? "\(Int(summary.remainingML)) ml to go"
                 : "target met")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water")
        .accessibilityValue("\(Int(summary.totalML)) of \(Int(summary.goalML)) millilitres")
    }

    private var bottle: some View {
        GeometryReader { proxy in
            let shape = RoundedRectangle(cornerRadius: proxy.size.width * 0.3, style: .continuous)

            ZStack(alignment: .bottom) {
                shape.fill(.quaternary.opacity(0.5))
                Rectangle()
                    .fill(tint)
                    .frame(height: proxy.size.height * fraction)
                shape.strokeBorder(.quaternary, lineWidth: 1.5)

                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(fraction > 0.55 ? Color.white : Color.secondary)
                    .frame(maxHeight: .infinity)
            }
            .clipShape(shape)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func logButton(_ millilitres: Int) -> some View {
        #if canImport(AppIntents)
        if #available(iOS 17.0, *) {
            Button(intent: LogWaterIntent(millilitres: millilitres)) {
                Text("\(millilitres)")
                    .font(.system(size: size == .medium ? 14 : 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: buttonHeight)
                    .background(tint.opacity(0.2), in: .rect(cornerRadius: 7))
                    .foregroundStyle(tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log \(millilitres) millilitres")
        }
        #endif
    }
}
#endif
