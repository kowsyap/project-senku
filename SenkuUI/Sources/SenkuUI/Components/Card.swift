import SwiftUI

/// A titled container. Used instead of `GroupBox`, which is unavailable on watchOS.
public struct Card<Content: View>: View {
    private let title: String?
    private let footnote: String?
    private let content: Content

    public init(
        _ title: String? = nil,
        footnote: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footnote = footnote
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
            }

            content

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Senku.Metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Senku.Metrics.cardCorner, style: .continuous)
                .fill(.quaternary.opacity(0.35))
        )
    }
}
