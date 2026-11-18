import Foundation
import Testing
@testable import SenkuCore

@Suite struct ProgressPhotoTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ day: Int, month: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 7))!
    }

    private func photo(_ pose: ProgressPhoto.Pose, day: Int, weight: Double = 80, weighIn: UUID = UUID()) -> ProgressPhoto {
        ProgressPhoto(weighInID: weighIn, date: self.day(day), weightKG: weight, pose: pose)
    }

    @Test func takesTheWeighInsDateAndWeight() throws {
        let weighIn = try WeighIn(date: day(3), weightKG: 81.4)
        let shot = ProgressPhoto(.side, of: weighIn)
        #expect(shot.weighInID == weighIn.id)
        #expect(shot.date == weighIn.date)
        #expect(shot.weightKG == 81.4)
        #expect(shot.fileName == "\(shot.id.uuidString).heic")
    }

    @Test func keptOldestFirst() {
        let late = photo(.front, day: 20)
        let early = photo(.front, day: 2)
        let album = ProgressAlbum([late, early])
        #expect(album.photos.map(\.id) == [early.id, late.id])
        #expect(album.latest(.front)?.id == late.id)
    }

    @Test func posesAreOnlyThoseWithPhotos() {
        let album = ProgressAlbum([photo(.back, day: 1), photo(.front, day: 2)])
        #expect(album.poses == [.front, .back])
        #expect(album.photos(.side).isEmpty)
        #expect(album.latest(.side) == nil)
    }

    @Test func aSecondPhotoOfThePoseReplacesTheFirst() {
        let weighIn = UUID()
        let first = photo(.front, day: 1, weighIn: weighIn)
        let side = photo(.side, day: 1, weighIn: weighIn)
        let retake = photo(.front, day: 1, weighIn: weighIn)

        let (album, replaced) = ProgressAlbum([first, side]).adding(retake)
        #expect(replaced?.id == first.id)
        #expect(Set(album.photos.map(\.id)) == [side.id, retake.id])
    }

    @Test func anotherWeighInsPhotoIsAdded() {
        let first = photo(.front, day: 1)
        let (album, replaced) = ProgressAlbum([first]).adding(photo(.front, day: 8))
        #expect(replaced == nil)
        #expect(album.photos(.front).count == 2)
    }

    @Test func aWeighInsPhotosAreFoundAndRemoved() {
        let weighIn = UUID()
        let front = photo(.front, day: 1, weighIn: weighIn)
        let back = photo(.back, day: 1, weighIn: weighIn)
        let other = photo(.front, day: 9)
        let album = ProgressAlbum([front, back, other])

        let theirs = album.photos(of: weighIn)
        #expect(Set(theirs.map(\.id)) == [front.id, back.id])
        #expect(album.removing(Set(theirs.map(\.id))).photos.map(\.id) == [other.id])
    }

    @Test func changeIsWholeDaysAndWeight() {
        let then = photo(.front, day: 1, weight: 84.2)
        let now = ProgressPhoto(weighInID: UUID(), date: day(15, month: 9).addingTimeInterval(-6 * 3600), weightKG: 80, pose: .front)
        let change = ProgressAlbum.change(from: then, to: now, calendar: calendar)
        #expect(change.days == 45)
        #expect(abs(change.weightKG - -4.2) < 0.0001)
    }
}
