import Foundation

/// A photograph of you, taken with a weigh-in.
///
/// It carries its own date and weight rather than only pointing at the
/// weigh-in: the comparison screen reads them on every photo, and a photo
/// should keep saying what you weighed that morning even if the weigh-in it
/// came with is later replaced by an imported backup.
///
/// The picture itself is a file named after `id`, kept apart from everything
/// else Senku stores — never in the JSON backup, where a year of photos would
/// turn a small file into a large one.
public struct ProgressPhoto: Codable, Hashable, Sendable, Identifiable {
    public enum Pose: String, Codable, CaseIterable, Sendable, Identifiable {
        case front
        case side
        case back

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .front: "Front"
            case .side: "Side"
            case .back: "Back"
            }
        }
    }

    public let id: UUID
    public let weighInID: UUID
    public let date: Date
    public let weightKG: Double
    public let pose: Pose

    public init(id: UUID = UUID(), weighInID: UUID, date: Date, weightKG: Double, pose: Pose) {
        self.id = id
        self.weighInID = weighInID
        self.date = date
        self.weightKG = weightKG
        self.pose = pose
    }

    public init(_ pose: Pose, of weighIn: WeighIn, id: UUID = UUID()) {
        self.init(id: id, weighInID: weighIn.id, date: weighIn.date, weightKG: weighIn.weightKG, pose: pose)
    }

    public var fileName: String { "\(id.uuidString).heic" }
}

/// Every progress photo, and what the comparison screen asks of them.
public struct ProgressAlbum: Sendable, Equatable {
    /// Oldest first.
    public let photos: [ProgressPhoto]

    public init(_ photos: [ProgressPhoto] = []) {
        self.photos = photos.sorted { $0.date < $1.date }
    }

    public var isEmpty: Bool { photos.isEmpty }

    /// The poses there is at least one photo of, in the usual order.
    public var poses: [ProgressPhoto.Pose] {
        ProgressPhoto.Pose.allCases.filter { pose in photos.contains { $0.pose == pose } }
    }

    /// One pose's photos, oldest first.
    public func photos(_ pose: ProgressPhoto.Pose) -> [ProgressPhoto] {
        photos.filter { $0.pose == pose }
    }

    public func latest(_ pose: ProgressPhoto.Pose) -> ProgressPhoto? {
        photos.last { $0.pose == pose }
    }

    public func photos(of weighInID: UUID) -> [ProgressPhoto] {
        photos.filter { $0.weighInID == weighInID }
    }

    /// `photo` added. A weigh-in has one photo per pose, so a second front
    /// photo for the same weigh-in replaces the first, which is handed back
    /// for its file to be deleted.
    public func adding(_ photo: ProgressPhoto) -> (album: ProgressAlbum, replaced: ProgressPhoto?) {
        let replaced = photos.first { $0.weighInID == photo.weighInID && $0.pose == photo.pose }
        let kept = photos.filter { $0.id != replaced?.id }
        return (ProgressAlbum(kept + [photo]), replaced)
    }

    public func removing(_ ids: Set<UUID>) -> ProgressAlbum {
        ProgressAlbum(photos.filter { !ids.contains($0.id) })
    }

    /// What changed between two photos: whole days apart, and the weight.
    public struct Change: Equatable, Sendable {
        public let days: Int
        public let weightKG: Double
    }

    public static func change(
        from then: ProgressPhoto,
        to now: ProgressPhoto,
        calendar: Calendar = .current
    ) -> Change {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: then.date),
            to: calendar.startOfDay(for: now.date)
        ).day ?? 0
        return Change(days: days, weightKG: now.weightKG - then.weightKG)
    }
}
