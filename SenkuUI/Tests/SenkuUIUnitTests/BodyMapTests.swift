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

    // MARK: - Highlighting

    private func part(_ id: String) throws -> BodyMapPart {
        try #require((BodyMapPart.front + BodyMapPart.back).first { $0.id == id })
    }

    /// The parts are finer than the picker's areas, from the same drawing:
    /// every one has to exist in both bodies, and be more than nothing.
    @Test(arguments: Sex.allCases)
    func everyPartIsDrawn(for sex: Sex) throws {
        let art = try #require(art)
        for side in BodySide.allCases {
            let drawn = art.side(side, for: sex)
            for part in BodyMapPart.parts(on: side) {
                for slug in part.slugs {
                    #expect(drawn.parts[slug] != nil, "\(sex) \(part.id): no slug \(slug)")
                }
                #expect(!part.path(in: drawn).isEmpty, "\(sex) \(part.id) draws nothing")
            }
        }
    }

    /// Every muscle region the catalogue scores has a part of its own or
    /// shares one — nothing an exercise trains is left off the body.
    @Test func everyRegionHasAPart() {
        let mapped = Set((BodyMapPart.front + BodyMapPart.back).flatMap(\.regionIDs))
        for region in ExerciseCatalogue.bundled.muscleRegions where region.workoutGroup.isMuscle {
            #expect(mapped.contains(region.id), "\(region.id) has no part")
        }
    }

    /// The chest's heads sit where the muscle has them: the clavicular along
    /// the top, the abdominal along the bottom, the sternocostal between —
    /// on both sides, mirrored, for both bodies.
    @Test(arguments: Sex.allCases)
    func theChestHeadsSitWhereTheMuscleHasThem(for sex: Sex) throws {
        let drawn = try #require(art).side(.front, for: sex)
        let chest = try #require(drawn.parts["chest"]).boundingRect
        let upper = try part("front.chest.upper").path(in: drawn).boundingRect
        let mid = try part("front.chest.mid").path(in: drawn).boundingRect
        let lower = try part("front.chest.lower").path(in: drawn).boundingRect

        #expect(abs(upper.minY - chest.minY) < 2)     // reaches the top
        #expect(abs(lower.maxY - chest.maxY) < 2)     // reaches the bottom
        #expect(upper.midY < mid.midY && mid.midY < lower.midY)
        // Both pieces carry each head, so each spans both sides of the body.
        for head in [upper, mid, lower] {
            #expect(head.minX < drawn.frame.midX && head.maxX > drawn.frame.midX)
        }
    }

    /// The point of the heads: an incline press and a decline press light
    /// different parts of the chest.
    @Test func inclineAndDeclineLightDifferentBands() throws {
        let catalogue = ExerciseCatalogue.bundled
        let incline = try #require(catalogue.exercises.first { $0.name == "Incline Barbell Bench Press" })
        let decline = try #require(catalogue.exercises.first { $0.name == "Decline Barbell Bench Press" })
        let upper = try part("front.chest.upper")
        let lower = try part("front.chest.lower")
        #expect((upper.share(of: incline.contributions) ?? 0) > (upper.share(of: decline.contributions) ?? 0))
        #expect((lower.share(of: decline.contributions) ?? 0) > (lower.share(of: incline.contributions) ?? 0))
    }

    @Test func aPartTakesItsHardestWorkedRegion() throws {
        let bench = try #require(ExerciseCatalogue.bundled.exercise("catalogue.bench.flat"))
        #expect(try part("front.chest.mid").share(of: bench.contributions) == 1.0)
        #expect(try part("back.triceps.lateral").share(of: bench.contributions) == 0.4)
        #expect(try part("back.lats").share(of: bench.contributions) == nil)
    }

    /// A bench press lends the triceps 40% — not enough on its own to call
    /// them trained; two pressing movements are.
    @Test func trainedMeansHalfAnExercisesWorth() throws {
        let bench = try #require(ExerciseCatalogue.bundled.exercise("catalogue.bench.flat"))
        let planned: Set<WorkoutGroup> = [.chest, .tricep]

        let one = BodyMapPart.coverage(of: [bench])
        #expect(try part("front.chest.mid").state(coverage: one, plannedGroups: planned) == .trained)
        #expect(try part("back.triceps.lateral").state(coverage: one, plannedGroups: planned) == .missed)

        let two = BodyMapPart.coverage(of: [bench, bench])
        #expect(try part("back.triceps.lateral").state(coverage: two, plannedGroups: planned) == .trained)
    }

    /// Red is for the day's own groups; a muscle nobody planned stays grey.
    @Test func onlyPlannedGroupsShowAsMissed() throws {
        let nothing = BodyMapPart.coverage(of: [])
        #expect(try part("front.quads").state(coverage: nothing, plannedGroups: [.chest]) == nil)
        #expect(try part("front.chest.upper").state(coverage: nothing, plannedGroups: [.chest]) == .missed)
    }

    @Test func coverageIsCappedAtWhole() throws {
        let bench = try #require(ExerciseCatalogue.bundled.exercise("catalogue.bench.flat"))
        #expect(BodyMapPart.coverage(of: [bench, bench, bench])["chest.mid"] == 1)
    }
}
