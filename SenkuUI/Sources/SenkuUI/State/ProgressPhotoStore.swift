#if !os(watchOS)
import Foundation
import ImageIO
import Observation
import UniformTypeIdentifiers
import SenkuCore

/// Progress photos: the pictures as HEIC files, and a small index of what
/// each one is.
///
/// Kept in the app's own Application Support folder, not the App Group: no
/// widget or watch shows them, and nothing else should be able to read them.
/// They are never saved to the Photos library, so they turn up nowhere else
/// on the phone. They are not in the JSON backup either, which stays small;
/// `exportFiles(in:)` hands them out separately. A device backup includes them,
/// as it does everything in Application Support.
@MainActor
@Observable
public final class ProgressPhotoStore {
    public static let shared = ProgressPhotoStore()

    public private(set) var album: ProgressAlbum

    private let folder: URL
    @ObservationIgnored private let cache = NSCache<NSString, ImageBox>()

    public init(folder: URL = ProgressPhotoStore.defaultFolder) {
        self.folder = folder
        self.album = Self.load(from: folder)
    }

    public nonisolated static var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "ProgressPhotos", directoryHint: .isDirectory)
    }

    public func url(for photo: ProgressPhoto) -> URL {
        folder.appending(path: photo.fileName)
    }

    // MARK: - Changing

    /// Saves `image` as the `pose` photo of `weighIn`, replacing any it had.
    @discardableResult
    public func add(_ image: CGImage, pose: ProgressPhoto.Pose, of weighIn: WeighIn) async -> ProgressPhoto? {
        let photo = ProgressPhoto(pose, of: weighIn)
        let file = url(for: photo)
        let folder = folder
        let written = await Task.detached(priority: .userInitiated) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return ProgressPhotoFile.write(image, to: file)
        }.value
        guard written else { return nil }

        let (next, replaced) = album.adding(photo)
        album = next
        if let replaced { removeFiles(of: [replaced]) }
        persist()
        return photo
    }

    public func delete(_ photo: ProgressPhoto) {
        album = album.removing([photo.id])
        removeFiles(of: [photo])
        persist()
    }

    /// A deleted weigh-in takes its photos with it.
    public func deletePhotos(of weighInID: UUID) {
        let theirs = album.photos(of: weighInID)
        guard !theirs.isEmpty else { return }
        album = album.removing(Set(theirs.map(\.id)))
        removeFiles(of: theirs)
        persist()
    }

    /// After a hard reset has removed the folder.
    public func reload() {
        cache.removeAllObjects()
        album = Self.load(from: folder)
    }

    /// Every photo and the index, gone. Called by the hard reset.
    public nonisolated static func wipe(_ folder: URL = defaultFolder) {
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - Reading

    /// The photo, downsized to `maxPixel` on its long side, and remembered.
    public func image(for photo: ProgressPhoto, maxPixel: Int) async -> CGImage? {
        let key = "\(photo.id.uuidString)-\(maxPixel)" as NSString
        if let box = cache.object(forKey: key) { return box.image }
        let file = url(for: photo)
        let image = await Task.detached(priority: .userInitiated) {
            ProgressPhotoFile.image(at: file, maxPixel: maxPixel)
        }.value
        if let image { cache.setObject(ImageBox(image), forKey: key) }
        return image
    }

    /// Copies of every photo, named so they sort and read on their own —
    /// "2026-11-18 Front 78.4 kg.heic" — in a fresh folder to share.
    public func exportFiles(in unitSystem: UnitSystem) throws -> [URL] {
        let out = FileManager.default.temporaryDirectory
            .appending(path: "Senku progress photos", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: out)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        var used: Set<String> = []
        var urls: [URL] = []
        for photo in album.photos {
            let base = ProgressPhotoName.make(photo, in: unitSystem)
            var name = base
            var count = 2
            while used.contains(name) {
                name = "\(base) \(count)"
                count += 1
            }
            used.insert(name)

            let target = out.appending(path: "\(name).heic")
            try FileManager.default.copyItem(at: url(for: photo), to: target)
            urls.append(target)
        }
        return urls
    }

    // MARK: - Storage

    private var indexURL: URL { folder.appending(path: "photos.json") }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(album.photos).write(to: indexURL, options: .atomic)
        } catch {
            // The files are written; only the index failed, and the next
            // change writes it again.
        }
    }

    private func removeFiles(of photos: [ProgressPhoto]) {
        for photo in photos {
            try? FileManager.default.removeItem(at: url(for: photo))
        }
        for key in cacheKeys(photos) { cache.removeObject(forKey: key) }
    }

    /// Cached sizes are not listed by `NSCache`, so the few in use are named.
    private func cacheKeys(_ photos: [ProgressPhoto]) -> [NSString] {
        photos.flatMap { photo in
            ProgressPhotoFile.sizes.map { "\(photo.id.uuidString)-\($0)" as NSString }
        }
    }

    private static func load(from folder: URL) -> ProgressAlbum {
        let index = folder.appending(path: "photos.json")
        guard let data = try? Data(contentsOf: index),
              let photos = try? JSONDecoder().decode([ProgressPhoto].self, from: data)
        else { return ProgressAlbum() }
        // A photo whose file has gone is left out rather than drawn as a hole.
        return ProgressAlbum(photos.filter {
            FileManager.default.fileExists(atPath: folder.appending(path: $0.fileName).path)
        })
    }
}

/// The name an exported photo is given: "2026-11-18 Front 78.4 kg".
enum ProgressPhotoName {
    static func make(_ photo: ProgressPhoto, in unitSystem: UnitSystem) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: photo.date)) \(photo.pose.title) \(Display.mass(photo.weightKG, in: unitSystem))"
    }
}

final class ImageBox: @unchecked Sendable {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

/// Reading and writing the pictures themselves.
public enum ProgressPhotoFile {
    /// Long side of a saved photo: plenty to compare, a few hundred KB as HEIC.
    public static let savedPixels = 1600
    /// The sizes the screens ask for.
    public static let thumbnailPixels = 400
    public static let screenPixels = 1200
    static let sizes = [thumbnailPixels, screenPixels, savedPixels]

    /// Upright and downsized, from whatever the camera or the photo library
    /// handed over — the orientation applied, not left as a tag.
    public static func upright(_ data: Data, maxPixel: Int = savedPixels) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return thumbnail(source, maxPixel: maxPixel)
    }

    static func image(at url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return thumbnail(source, maxPixel: maxPixel)
    }

    private static func thumbnail(_ source: CGImageSource, maxPixel: Int) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    }

    static func write(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.heic.identifier as CFString, 1, nil
        ) else { return false }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: 0.7,
        ] as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }
}
#endif
