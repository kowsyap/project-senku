import SwiftUI

/// A small right-aligned text field for entering a number directly.
///
/// Editing is done against a string rather than the bound value, because
/// clamping every keystroke makes typing impossible: the first character of
/// "175" is "1", which a 120–220 range would immediately rewrite to 120. The
/// value is parsed and clamped when editing ends instead.
public struct NumericField: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let decimals: Int
    private let unit: String?
    private let width: CGFloat

    @State private var text: String = ""
    @FocusState private var isEditing: Bool

    public init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        decimals: Int = 0,
        unit: String? = nil,
        width: CGFloat = 62
    ) {
        _value = value
        self.range = range
        self.decimals = decimals
        self.unit = unit
        self.width = width
    }

    public var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $text)
                .focused($isEditing)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .textFieldStyle(.plain)
                .frame(width: width)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.quaternary.opacity(isEditing ? 0.65 : 0.35))
                )
                #if os(iOS)
                .keyboardType(decimals > 0 ? .decimalPad : .numberPad)
                .submitLabel(.done)
                #endif

            if let unit {
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { text = formatted(value) }
        .onChange(of: value) { _, newValue in
            // Track the slider while it moves, but never fight the typist.
            if !isEditing { text = formatted(newValue) }
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                text = formatted(value)
            } else {
                commit()
            }
        }
        .onSubmit { isEditing = false }
        .accessibilityLabel(unit.map { "Value in \($0)" } ?? "Value")
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.\(decimals)f", value)
    }

    /// Parses what was typed, clamps it into range, and snaps the text back to
    /// canonical form. Unparseable input reverts rather than zeroing the field.
    private func commit() {
        guard let parsed = Self.parse(text, into: range) else {
            text = formatted(value)
            return
        }
        value = parsed
        text = formatted(parsed)
    }

    /// Reads typed text as a number inside `range`, or nil if it is not one.
    ///
    /// Comma is accepted as a decimal separator, since that is what much of the
    /// world types and the number pad offers whichever the locale prefers.
    static func parse(_ text: String, into range: ClosedRange<Double>) -> Double? {
        let normalised = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)

        guard let parsed = Double(normalised), parsed.isFinite else { return nil }
        return min(range.upperBound, max(range.lowerBound, parsed))
    }
}
