#if os(iOS)
import SwiftUI

/// Where you decide whether your food photographs leave the phone.
///
/// ## Why the wording here is so blunt
///
/// Every other screen in this app can promise that nothing goes anywhere,
/// because nothing does. This one is the door out, and a settings toggle that
/// undersells what it turns on is how somebody ends up having sent a year of
/// meals to a company they did not think about. So it says plainly what is
/// sent, when, and what Google may do with it on each tier — and the sending
/// stays off until somebody reads that and decides.
@available(iOS 27, *)
struct FoodIntelligenceSettings: View {
    @State private var isEnabled = GeminiAccount.isEnabled
    @State private var key = ""
    @State private var hasStoredKey = GeminiAccount.key != nil
    @State private var saveFailed = false

    var body: some View {
        Form {
            Section {
                Toggle("Read photos with Gemini", isOn: $isEnabled)
                    .disabled(!hasStoredKey)
            } header: {
                Text("Google Gemini")
            }

            Section {
                SecureField(hasStoredKey ? "Stored — type to replace" : "API key", text: $key)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    // Borderless on both: without it a row containing two
                    // buttons behaves as one tappable row, and whichever is
                    // first swallows the tap wherever you land.
                    Button("Save key") { save() }
                        .buttonStyle(.borderless)
                        .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)

                    if hasStoredKey {
                        Spacer()
                        Button("Remove key", role: .destructive) { clear() }
                            .buttonStyle(.borderless)
                    }
                }
            } header: {
                Text("Key")
            } footer: {
                // Markdown rather than a Link view: it keeps the sentence
                // reading as a sentence, and SwiftUI makes the span tappable
                // and opens it in Safari all the same.
                Text("Free from [Google AI Studio](https://aistudio.google.com/apikey).")
            }
        }
        .navigationTitle("Photo Reading")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isEnabled) { _, new in GeminiAccount.isEnabled = new }
        .alert("That key could not be saved.", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The Keychain refused it. Nothing was stored.")
        }
    }

    private func save() {
        guard GeminiAccount.save(key) else {
            saveFailed = true
            return
        }
        key = ""
        hasStoredKey = true
        Feedback.control()
    }

    private func clear() {
        GeminiAccount.clear()
        hasStoredKey = false
        // Turned off as well as forgotten: leaving the switch on with no key
        // behind it would read as working and fail on the next photograph.
        isEnabled = false
        GeminiAccount.isEnabled = false
        key = ""
    }
}
#endif
