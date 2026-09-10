import SwiftUI
import SenkuCore

/// Surfaces a caveat attached to a plan.
///
/// These are shown alongside results rather than blocking them: the user still
/// gets their number, with the context that makes it honest.
public struct AdvisoryBanner: View {
    private let advisory: Advisory

    public init(_ advisory: Advisory) {
        self.advisory = advisory
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: advisory.severity.symbol)
                .foregroundStyle(advisory.severity.tint)
                .font(.callout)
                .accessibilityHidden(true)

            Text(advisory.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(advisory.severity.tint.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
    }
}
