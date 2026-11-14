#if !os(watchOS)
import SwiftUI
import ImageIO

/// An exercise's poses, start and peak, swapped every second or so — the
/// closest a pair of stills comes to showing the movement.
///
/// Fetched the first time the exercise is opened and kept, so the second time
/// is instant and works offline. While loading it holds its space; if nothing
/// can be had — offline, never fetched — it takes none, and the sheet looks
/// as it did before pictures.
struct ExercisePictures: View {
    let urls: [URL]
    let name: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var images: [CGImage] = []
    @State private var isLoading = true

    private static let beat = 1.1

    var body: some View {
        Group {
            if !images.isEmpty {
                pictures
            } else if isLoading {
                frame { ProgressView() }
            }
        }
        .task(id: urls) {
            isLoading = true
            var loaded: [CGImage] = []
            for url in urls {
                if let image = await ExercisePictureStore.shared.image(at: url) { loaded.append(image) }
            }
            images = loaded
            isLoading = false
        }
    }

    @ViewBuilder
    private var pictures: some View {
        if images.count == 1 || reduceMotion {
            // Still, side by side, when motion is turned down.
            HStack(spacing: 8) {
                ForEach(images.indices, id: \.self) { index in
                    frame { picture(images[index]) }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
        } else {
            TimelineView(.periodic(from: .now, by: Self.beat)) { context in
                let shown = Int(context.date.timeIntervalSinceReferenceDate / Self.beat) % images.count
                frame {
                    ZStack {
                        ForEach(images.indices, id: \.self) { index in
                            picture(images[index]).opacity(index == shown ? 1 : 0)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: shown)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
        }
    }

    private var label: String {
        images.count > 1 ? "\(name), start and finish positions" : name
    }

    private func picture(_ image: CGImage) -> some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFit()
    }

    /// Square, rounded, no taller than a third of a half-height sheet.
    private func frame<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: 200)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(maxWidth: .infinity)
    }
}

/// Exercise pictures, fetched once and kept in the caches folder.
///
/// The cache is the point: RepDB's site promises nothing about staying up, so
/// every picture opened once is one that no longer depends on it. Caches can
/// be cleared by iOS when space runs low; a cleared picture is fetched again.
actor ExercisePictureStore {
    static let shared = ExercisePictureStore()

    private let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appending(path: "ExercisePictures", directoryHint: .isDirectory)
    private var memory: [URL: CGImage] = [:]
    private var loading: [URL: Task<CGImage?, Never>] = [:]

    func image(at url: URL) async -> CGImage? {
        if let image = memory[url] { return image }
        if let task = loading[url] { return await task.value }

        let file = folder.appending(path: url.lastPathComponent)
        let folder = folder
        let task = Task<CGImage?, Never> {
            if let data = try? Data(contentsOf: file), let image = Self.decode(data) { return image }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let image = Self.decode(data)
            else { return nil }
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            return image
        }
        loading[url] = task
        let image = await task.value
        loading[url] = nil
        if let image { memory[url] = image }
        return image
    }

    /// WebP included — ImageIO reads it on every OS Senku runs on.
    private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
#endif
