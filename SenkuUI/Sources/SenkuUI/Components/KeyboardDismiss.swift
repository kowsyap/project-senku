#if !os(watchOS)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// Gives numeric entry a way out.
    ///
    /// The number and decimal pads have no return key, so without this a field
    /// can be typed into but not left. Adds a Done button above the keyboard and
    /// lets a scroll dismiss it too.
    public func dismissableKeyboard() -> some View {
        #if os(iOS)
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
        #else
        self
        #endif
    }
}
#endif
