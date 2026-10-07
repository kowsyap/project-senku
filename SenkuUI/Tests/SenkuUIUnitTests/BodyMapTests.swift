import Foundation
import SwiftUI
import Testing
import SenkuCore
@testable import SenkuUI

/// The map is two files that have to agree — the drawing and the list of
/// which drawn muscle stands for which catalogue region — and nothing at
/// runtime would notice if they stopped. An area pointing at a slug the
/// drawing does not have is simply never drawn.
@Suite struct BodyMapTests {
    private let art = BodyMapArt.shared

    @Test func theDrawingLoads() throws {
        let art = try #require(art, "BodyMap.json did not load")
        for sex in Sex.allCases {
            for side in BodySide.allCases {
                #expect(!art.side(side, for: sex).outline.isEmpty, "\(sex) \(side) has no outline")
            }
        }
    }

    /// Both bodies, both sides: the areas are shared, so a slug the female
    /// drawing names differently would leave a hole in only one of them.
    @Test(arguments: Sex.allCases)
    func everyAreaIsDrawn(for sex: Sex) throws {
        let art = try #require(art)
        for side in BodySide.allCases {
            for area in BodyMapArea.areas(on: side) {
                for slug in area.slugs {
                    let part = try #require(art.side(side, for: sex).parts[slug],
                                            "\(sex) \(area.id) names missing slug \(slug)")
                    #expect(!part.isEmpty, "\(sex) \(area.id): \(slug) is empty")
                }
            }
        }
    }

    @Test func theTwoBodiesAreDifferentDrawings() throws {
        let art = try #require(art)
        #expect(art.male.front.frame != art.female.front.frame)
    }

    /// Muscles on the body, and cardio's one region at the heart beside it —
    /// so nothing the catalogue scores is out of reach from the map.
    @Test func everyRegionIsSomewhereOnTheMap() {
        let catalogue = ExerciseCatalogue.bundled
        let onBody = Set(BodySide.allCases.flatMap { BodyMapArea.areas(on: $0) }.flatMap(\.regionIDs))
        let mapped = onBody.union(BodyMapArea.cardio.regionIDs)

        for region in catalogue.muscleRegions {
            #expect(mapped.contains(region.id), "\(region.id) is not on the map")
        }
        #expect(mapped.isSubset(of: Set(catalogue.muscleRegions.map(\.id))))
        // And nothing but muscles on the body itself.
        let bodyIsAllMuscle = catalogue.muscleRegions
            .filter { onBody.contains($0.id) }
            .allSatisfy { $0.workoutGroup.isMuscle }
        #expect(bodyIsAllMuscle)
    }

    @Test func theHeartListsTheCardio() {
        let catalogue = ExerciseCatalogue.bundled
        let trains = catalogue.exercises.filter { exercise in
            BodyMapArea.cardio.regionIDs.contains { exercise.contributions[$0] != nil }
        }
        #expect(!trains.isEmpty)
        #expect(Set(catalogue.exercises(in: .cardio).map(\.id)).isSubset(of: Set(trains.map(\.id))))
    }

    @Test func areaIDsAreUnique() {
        let all = BodySide.allCases.flatMap { BodyMapArea.areas(on: $0) }.map(\.id)
        #expect(Set(all).count == all.count)
    }

    @Test func theParserReadsTheFourCommands() {
        let square = BodyMapArt.path("M10 10L20 10C20 15 20 15 20 20L10 20Z")
        let box = square.boundingRect
        #expect(box.minX == 10 && box.minY == 10)
        #expect(box.maxX == 20 && box.maxY == 20)
    }

    /// Each side sits inside the frame it is fitted by, or part of the body
    /// would be cut off at the edge of the map.
    @Test func everySideFitsItsFrame() throws {
        let art = try #require(art)
        for sex in Sex.allCases {
            for side in BodySide.allCases {
                let drawn = art.side(side, for: sex)
                #expect(drawn.frame.insetBy(dx: -1, dy: -1).contains(drawn.outline.boundingRect),
                        "\(sex) \(side) spills outside its frame")
            }
        }
    }

    /// The hint, the map and the ground under it add up to the whole space,
    /// so the line the figures stand on is the line the heart is placed on.
    @Test(arguments: [CGSize(width: 440, height: 760), CGSize(width: 375, height: 520), CGSize(width: 1024, height: 900)])
    func theHeartStandsWhereTheFiguresDo(in space: CGSize) {
        let map = BodyMapPicker.mapHeight(in: space)
        let ground = BodyMapPicker.groundInset(in: space)
        let top = BodyMapPicker.hintHeight + BodyMapPicker.hintGap
        #expect(abs(top + map + ground - space.height) < 0.001 || ground == BodyMapPicker.bottomPadding)
        #expect(map <= space.height)
    }

    /// Fitted to the body rather than the library's viewBox, every figure's
    /// feet reach the bottom of its frame — the female back's viewBox left 1%
    /// under them and the male's 6.6%, which stood them at different heights.
    @Test func everyFigureStandsOnItsFrame() throws {
        let art = try #require(art)
        for sex in Sex.allCases {
            for side in BodySide.allCases {
                let drawn = art.side(side, for: sex)
                #expect(drawn.frame.maxY - drawn.outline.boundingRect.maxY <= 4.5, "\(sex) \(side) floats above its frame")
            }
        }
    }

    /// The fit maps the frame's corners onto the rect, wherever the frame
    /// starts — the female front's begins at (-50, -40), not the origin.
    @Test func theShapeFitsAnOffsetFrame() {
        let frame = CGRect(x: -50, y: -40, width: 100, height: 200)
        let corners = Path(CGRect(x: -50, y: -40, width: 100, height: 200))
        let drawn = BodyArtShape(art: corners, frame: frame)
            .path(in: CGRect(x: 0, y: 0, width: 50, height: 100))
            .boundingRect
        #expect(abs(drawn.minX) < 0.001 && abs(drawn.minY) < 0.001)
        #expect(abs(drawn.maxX - 50) < 0.001 && abs(drawn.maxY - 100) < 0.001)
    }
}
