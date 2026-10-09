#if !os(watchOS)
import SwiftUI

/// Who made Senku, where your data goes, and what it is built on.
///
/// Short on purpose: a version to quote in a bug report, the one privacy
/// answer people want before they log a weigh-in, the disclaimer the README
/// carries and the app did not, and the license notices.
///
/// The notices are not decoration. The body drawings come from an MIT library,
/// and MIT asks for its copyright and permission notice in every copy of the
/// software — which includes the app on someone's phone, not just the
/// repository. `THIRD_PARTY_NOTICES.md` alone never reached the phone.
struct AboutView: View {
    static let repository = URL(string: "https://github.com/kowsyap/project-senku")!
    static let issues = URL(string: "https://github.com/kowsyap/project-senku/issues")!
    static let license = URL(string: "https://github.com/kowsyap/project-senku/blob/main/LICENSE")!

    @State private var isShowingNotice = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image("SenkuMark", bundle: .module)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 44)
                        Text("SENKU")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .tracking(1.6)
                    }
                    Text("Strength · Energy · Nutrition · Knowledge · Utility")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(version)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                Link(destination: Self.repository) {
                    Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: Self.issues) {
                    Label("Report a problem", systemImage: "exclamationmark.bubble")
                }
            } header: {
                Text("Made by kowsyap")
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Section {
                // One row, so the list draws no lines between the points.
                VStack(alignment: .leading, spacing: 10) {
                    Text("Everything you log stays on this iPhone and your Apple Watch. There is no account, no cloud and no tracking.")
                        .font(.subheadline)
                    bullet("Apple Health: Senku only writes what you switch on, and never reads.")
                    bullet("Food photos are read on your iPhone by Apple Intelligence. If you switch on Gemini under Photo reading, the photo or label text goes to Google instead.")
                    bullet("Anime posters load from the addresses you add.")
                }
                .padding(.vertical, 4)
            } header: {
                Text("Your data")
            }

            Section {
                Text("Senku's numbers are estimates from published formulas. Each one says where it came from, but none of it replaces a doctor. Talk to one before an aggressive diet or training plan.")
                    .font(.subheadline)
            } header: {
                Text("Not medical advice")
            }

            Section {
                Text("Senku is open source under the MIT License. The icon artwork is not covered and belongs to its respective owners.")
                    .font(.subheadline)
                Link(destination: Self.license) {
                    Label("Read the license", systemImage: "doc.text")
                }
            } header: {
                Text("License")
            }

            Section {
                DisclosureGroup(isExpanded: $isShowingNotice) {
                    Text(Self.reflowed(Self.bodyHighlighterNotice))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("react-native-body-highlighter")
                            .font(.subheadline.weight(.semibold))
                        Text("The front and back body figures · MIT License")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Acknowledgements")
            }
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .senkuBottomBarInset()
    }

    /// The notice's own line breaks are for an 80-column file; on a phone they
    /// fought the wrapping. Same words, joined into paragraphs.
    static func reflowed(_ text: String) -> String {
        text.components(separatedBy: "\n\n")
            .map { $0.replacingOccurrences(of: "\n", with: " ") }
            .joined(separator: "\n\n")
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(.secondary)
            Text(text).font(.subheadline)
        }
    }

    /// Word for word as the library ships it — a test holds it to
    /// THIRD_PARTY_NOTICES.md, so the two cannot drift.
    static let bodyHighlighterNotice = """
    MIT License

    Copyright (c) 2022 ELABBASSI Hicham

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """
}
#endif
