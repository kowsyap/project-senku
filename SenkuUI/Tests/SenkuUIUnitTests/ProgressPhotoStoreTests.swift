import CoreGraphics
import ImageIO
import Foundation
import Testing
@testable import SenkuUI
import SenkuCore

@MainActor
@Suite struct ProgressPhotoStoreTests {
    private let folder = FileManager.default.temporaryDirectory
        .appending(path: "ProgressPhotoStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    private func picture(width: Int = 30, height: Int = 40) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private func weighIn(_ kg: Double, daysAgo: Double = 0) throws -> WeighIn {
        try WeighIn(date: Date(timeIntervalSince1970: 1_790_000_000 - daysAgo * 86_400), weightKG: kg)
    }

    @Test func savedPhotosComeBackAfterRelaunch() async throws {
        defer { ProgressPhotoStore.wipe(folder) }
        let store = ProgressPhotoStore(folder: folder)
        let entry = try weighIn(80.2)
        let saved = try #require(await store.add(picture(), pose: .front, of: entry))

        #expect(FileManager.default.fileExists(atPath: store.url(for: saved).path))
        let reopened = ProgressPhotoStore(folder: folder)
        #expect(reopened.album.photos == [saved])
        let image = await reopened.image(for: saved, maxPixel: 400)
        #expect(image?.height == 40)
    }

    @Test func aRetakeReplacesTheFileToo() async throws {
        defer { ProgressPhotoStore.wipe(folder) }
        let store = ProgressPhotoStore(folder: folder)
        let entry = try weighIn(80.2)
        let first = try #require(await store.add(picture(), pose: .side, of: entry))
        let retake = try #require(await store.add(picture(), pose: .side, of: entry))

        #expect(store.album.photos == [retake])
        #expect(!FileManager.default.fileExists(atPath: store.url(for: first).path))
    }

    @Test func deletingAWeighInsPhotosLeavesTheOthers() async throws {
        defer { ProgressPhotoStore.wipe(folder) }
        let store = ProgressPhotoStore(folder: folder)
        let old = try weighIn(84, daysAgo: 30)
        let new = try weighIn(80)
        await store.add(picture(), pose: .front, of: old)
        await store.add(picture(), pose: .back, of: old)
        let kept = try #require(await store.add(picture(), pose: .front, of: new))

        store.deletePhotos(of: old.id)
        #expect(store.album.photos == [kept])
        #expect(ProgressPhotoStore(folder: folder).album.photos == [kept])
    }

    @Test func aPhotoWhoseFileIsGoneIsLeftOut() async throws {
        defer { ProgressPhotoStore.wipe(folder) }
        let store = ProgressPhotoStore(folder: folder)
        let photo = try #require(await store.add(picture(), pose: .front, of: weighIn(80)))
        try FileManager.default.removeItem(at: store.url(for: photo))
        #expect(ProgressPhotoStore(folder: folder).album.isEmpty)
    }

    @Test func exportedFilesAreNamedByDatePoseAndWeight() async throws {
        defer { ProgressPhotoStore.wipe(folder) }
        let store = ProgressPhotoStore(folder: folder)
        let entry = try weighIn(80.24)
        await store.add(picture(), pose: .front, of: entry)
        await store.add(picture(), pose: .back, of: entry)

        let urls = try store.exportFiles(in: .metric)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: entry.date)
        #expect(Set(urls.map(\.lastPathComponent)) == ["\(day) Front 80.2 kg.heic", "\(day) Back 80.2 kg.heic"])
        #expect(urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    @Test func wipeLeavesNothing() async throws {
        let store = ProgressPhotoStore(folder: folder)
        await store.add(picture(), pose: .front, of: try weighIn(80))
        ProgressPhotoStore.wipe(folder)
        store.reload()
        #expect(store.album.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test func uprightAppliesTheOrientationTag() throws {
        // A 40×30 landscape frame tagged "rotated" (6) is a 30×40 portrait.
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, picture(width: 40, height: 30), [
            kCGImagePropertyOrientation: 6,
        ] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))

        let image = try #require(ProgressPhotoFile.upright(data as Data))
        #expect(image.width == 30)
        #expect(image.height == 40)
    }
}

