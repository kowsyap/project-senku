#if os(iOS)
import UIKit

/// Puts the cursor at the end of a number field when it is tapped into.
///
/// Left to UIKit, the cursor lands wherever the finger did — which in a field
/// holding "40" is as often between the digits as after them, and the next
/// backspace takes out the wrong one. Every number in the app is edited by
/// adding to or deleting from its end, so that is where the cursor goes.
///
/// One observer for the whole app rather than a modifier on each field, so a
/// field added later behaves the same without anyone remembering to ask. Text
/// fields are left alone: tapping into the middle of a title to fix a typo is
/// what that tap is for.
@MainActor
public final class NumberFieldCursor: NSObject {
    private static let shared = NumberFieldCursor()
    private var isInstalled = false

    /// Call once at launch.
    public static func install() {
        guard !shared.isInstalled else { return }
        shared.isInstalled = true
        NotificationCenter.default.addObserver(
            shared,
            selector: #selector(began(_:)),
            name: UITextField.textDidBeginEditingNotification,
            object: nil
        )
    }

    @objc private func began(_ note: Notification) {
        guard let field = note.object as? UITextField,
              [.numberPad, .decimalPad, .asciiCapableNumberPad].contains(field.keyboardType)
        else { return }

        // Next turn of the run loop: UIKit places the cursor at the tap after
        // editing begins, and would otherwise put it straight back.
        Task { @MainActor in
            let end = field.endOfDocument
            field.selectedTextRange = field.textRange(from: end, to: end)
        }
    }
}
#endif
