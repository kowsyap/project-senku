import SwiftUI

/// A label on the left, a value on the right, optionally emphasised.
public struct StatRow: View {
    private let label: String
    private let value: String
    private let detail: String?
    private let isProminent: Bool
    private let tint: Color?

    public init(
        _ label: String,
        value: String,
        detail: String? = nil,
        isProminent: Bool = false,
        tint: Color? = nil
    ) {
        self.label = label
        self.value = value
        self.detail = detail
        self.isProminent = isProminent
        self.tint = tint
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(isProminent ? .body.weight(.medium) : .subheadline)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Text(value)
                .font(isProminent ? .title3.weight(.semibold) : .subheadline.weight(.medium))
                .foregroundStyle(tint ?? .primary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
