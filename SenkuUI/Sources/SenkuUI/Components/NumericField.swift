import SwiftUI

/// A small right-aligned text field for entering a number directly.
///
/// Editing is done against a string rather than the bound value, because
/// clamping every keystroke makes typing impossible: the first character of
/// "175" is "1", which a 120–220 range would immediately rewrite to 120. The
/// value is parsed and clamped when editing ends instead.
///
/// ## Hitting it
///
/// The field used to be about 26 points tall — a text row with four points of
/// padding — which is well under the 44 points a finger needs, and is why it
/// felt unresponsive rather than small: taps were landing beside it and doing
/// nothing. It is now a 44-point target whose whole area is tappable, including
/// the padding and the unit beside it, so a tap anywhere near the number starts
/// editing it.
public struct NumericField: View {
    @Binding private var value: Double?
    private let range: ClosedRange<Double>
    private let decimals: Int
    private let unit: String?
    private let unitWidth: CGFloat
    private let width: CGFloat
    private let placeholder: String
    private let identifier: String?

    @State private var text: String = ""
    @FocusState private var isEditing: Bool

    /// An empty field means "not answered", not zero, which is why the value is
    /// optional: the calculator now starts blank and has to be able to tell the
    /// difference between a number the user chose and one it invented.
    public init(
        value: Binding<Double?>,
        range: ClosedRange<Double>,
        decimals: Int = 0,
        unit: String? = nil,
        unitWidth: CGFloat = 26,
        width: CGFloat = 62,
        placeholder: String = "—",
        identifier: String? = nil
    ) {
        _value = value
        self.range = range
        self.decimals = decimals
        self.unit = unit
        self.unitWidth = unitWidth
        self.width = width
        self.placeholder = placeholder
        self.identifier = identifier
    }

    /// For fields that always hold a number, such as a value already chosen.
    public init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        decimals: Int = 0,
        unit: String? = nil,
        width: CGFloat = 62,
        identifier: String? = nil
    ) {
        self.init(
            value: Binding(
                get: { value.wrappedValue },
                set: { (newValue: Double?) in
                    // A non-optional field cannot be un-answered, so clearing
                    // it leaves the last value in place.
                    if let newValue { value.wrappedValue = newValue }
                }
            ),
            range: range, decimals: decimals, unit: unit, width: width,
            identifier: identifier
        )
    }

    public var body: some View {
        HStack(spacing: 6) {
            TextField(placeholder, text: $text)
                .accessibilityIdentifier(identifier ?? "")
                .focused($isEditing)
                .multilineTextAlignment(.trailing)
                .font(.body.weight(.medium))
                .monospacedDigit()
                .textFieldStyle(.plain)
                .frame(width: width)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quaternary.opacity(isEditing ? 0.7 : 0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Senku.Palette.protein.opacity(isEditing ? 0.9 : 0), lineWidth: 2)
                )
                // Without this the gaps inside the field are not hittable, so a
                // tap either side of the digits falls through to the card.
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                #if os(iOS)
                .keyboardType(decimals > 0 ? .decimalPad : .numberPad)
                .submitLabel(.done)
                #endif

            if let unit {
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    // A fixed column for the unit, so "kg", "cm" and "yrs" all
                    // put their fields at the same place down the form. Without
                    // it the widest unit drags its own row's box out of line
                    // with every other.
                    .frame(width: unitWidth, alignment: .leading)
                    .lineLimit(1)
            }
        }
        // The unit is part of the target too: nobody aims at the number and
        // means "not the kg".
        .contentShape(Rectangle())
        .onTapGesture { isEditing = true }
        .onAppear { text = formatted(value) }
        .onChange(of: value) { _, newValue in
            // Track the slider while it moves, but never fight the typist.
            if !isEditing { text = formatted(newValue) }
        }
        .onChange(of: text) { _, typed in
            // Commit while typing, not only on blur. Committing only on blur
            // meant that typing a number and going straight to a button left
            // the value unread — the field showed 80 and the form still said
            // Weight was missing. Clamping stays on blur: "1" on the way to
            // "180" must not be rewritten to the minimum mid-keystroke.
            guard isEditing else { return }
            let trimmed = typed.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                value = nil
            } else if let parsed = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
                      parsed.isFinite {
                value = parsed
            }
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

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.\(decimals)f", value)
    }

    /// Parses what was typed, clamps it into range, and snaps the text back to
    /// canonical form. Unparseable input reverts rather than zeroing the field.
    private func commit() {
        // Clearing the field is a deliberate act: it un-answers the question
        // rather than reverting to whatever was there before.
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            value = nil
            text = ""
            return
        }
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
