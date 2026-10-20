import SwiftUI

/// A label on the left, a value on the right, optionally emphasised.
public struct StatRow: View {
    private let label: String
    private let value: String
    private let detail: String?
    private let isProminent: Bool
    private let tint: Color?
    /// A note behind an info button beside the value, and the button's colour.
    private let info: (text: String, tint: Color)?

    public init(
        _ label: String,
        value: String,
        detail: String? = nil,
        isProminent: Bool = false,
        tint: Color? = nil,
        info: (text: String, tint: Color)? = nil
    ) {
        self.label = label
        self.value = value
        self.detail = detail
        self.isProminent = isProminent
        self.tint = tint
        self.info = info
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

            if let info {
                InfoButton(info.text, tint: info.tint)
            }
        }
        // Read as one line, unless there is a button in it to reach.
        .accessibilityElement(children: info == nil ? .combine : .contain)
    }
}

/// An ⓘ that shows a short note in a popover — for the sentence that
/// explains a figure, kept beside the figure instead of in a banner below it.
public struct InfoButton: View {
    private let text: String
    private let tint: Color

    @State private var isShowing = false

    public init(_ text: String, tint: Color = .secondary) {
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        Button {
            isShowing = true
        } label: {
            Image(systemName: "info.circle")
                .font(.footnote)
                .foregroundStyle(tint)
                // A bigger target than the glyph, without a bigger glyph.
                .padding(6)
                .contentShape(Rectangle())
                .padding(-6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More information")
        .accessibilityHint(text)
        #if os(watchOS)
        .sheet(isPresented: $isShowing) {
            ScrollView { Text(text).font(.footnote) }
        }
        #else
        .popover(isPresented: $isShowing) {
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
                .padding()
                .presentationCompactAdaptation(.popover)
        }
        #endif
    }
}
