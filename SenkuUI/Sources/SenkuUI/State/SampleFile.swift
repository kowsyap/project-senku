import Foundation

/// The example import file — one of everything Import Data takes — as the app
/// carries it, for "Sample File" to hand out. A copy of
/// `docs/import-example.json`; a test keeps the two the same.
enum SampleFile {
    static var url: URL? {
        Bundle.module.url(forResource: "import-example", withExtension: "json")
    }
}
