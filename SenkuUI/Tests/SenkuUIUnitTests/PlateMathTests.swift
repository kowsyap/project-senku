import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// The stops everyone knows, and the ones nobody does.
@Suite struct PlateMathTests {
    @Test func theFamiliarPoundStops() {
        #expect(PlateMath.load(target: 135, using: .pounds).perSide == [45])
        #expect(PlateMath.load(target: 225, using: .pounds).perSide == [45, 45])
        #expect(PlateMath.load(target: 315, using: .pounds).perSide == [45, 45, 45])
    }

    /// The ones people actually stop and count.
    @Test func theAwkwardOnesInBetween() {
        #expect(PlateMath.load(target: 185, using: .pounds).perSide == [45, 25])
        // 45 + 35, not 45 + 25 + 10: the 35s are on the rack, and fewer plates
        // is fewer things to load.
        #expect(PlateMath.load(target: 205, using: .pounds).perSide == [45, 35])
        #expect(PlateMath.load(target: 245, using: .pounds).perSide == [45, 45, 10])
        #expect(PlateMath.load(target: 255, using: .pounds).perSide == [45, 45, 10, 5])
    }

    @Test func kilogramsToo() {
        let load = PlateMath.load(target: 102.5, using: .kilograms)

        #expect(load.perSide == [25, 15, 1.25])
        #expect(load.isExact)
    }

    @Test func anEmptyBarIsAnEmptyBar() {
        let load = PlateMath.load(target: 45, using: .pounds)

        #expect(load.perSide.isEmpty)
        #expect(load.total == 45)
        #expect(load.isExact)
        #expect(load.description == "")
    }

    /// Asking for less than the bar weighs is not a loading problem.
    @Test func belowTheBarLoadsNothing() {
        let load = PlateMath.load(target: 30, using: .pounds)

        #expect(load.perSide.isEmpty)
        #expect(load.total == 45)
        #expect(!load.isExact)
    }

    /// The half of this worth having: a gym without small plates cannot build
    /// every number, and the app should say so before the bar is on your back.
    @Test func anUnbuildableTargetReportsWhatItCanReach() {
        let noSmallPlates = PlateSet(unit: .imperial, bar: 45, plates: [45, 25, 10])
        let load = PlateMath.load(target: 190, using: noSmallPlates)

        #expect(!load.isExact)
        #expect(load.total == 185)
        #expect(load.perSide == [45, 25])
    }

    @Test func theSmallestStepIsTwiceTheSmallestPlate() {
        #expect(PlateSet.pounds.smallestStep == 5)
        #expect(PlateSet.kilograms.smallestStep == 2.5)
        #expect(PlateSet(unit: .imperial, bar: 45, plates: [45, 25, 10]).smallestStep == 20)
    }

    /// The app stores kilograms whatever the plates say, so the round trip has
    /// to land on the number the bar can actually be built to.
    @Test func poundPlatesFromAKilogramWeight() {
        let kilos = Convert.kilograms(fromPounds: 225)
        let load = PlateMath.load(kilograms: kilos, using: .pounds)

        #expect(load.perSide == [45, 45])
        #expect(load.isExact)
    }

    /// The stepper's rule: a number off the ladder is snapped onto it, so "+"
    /// from 227 lands on a weight the rack can build.
    @Test func snappingLandsOnSomethingLoadable() {
        let rack = PlateSet.pounds   // 45 lb bar, 5 lb steps

        #expect(rack.snapped(227) == 225)
        #expect(rack.snapped(228) == 230)
        #expect(rack.snapped(225) == 225)
    }

    @Test func snappingNeverGoesBelowTheBar() {
        #expect(PlateSet.pounds.snapped(10) == 45)
        #expect(PlateSet.kilograms.snapped(0) == 20)
    }

    @Test func aRackWithoutSmallPlatesSnapsFurther() {
        let coarse = PlateSet(unit: .imperial, bar: 45, plates: [45, 25, 10])

        #expect(coarse.smallestStep == 20)
        #expect(coarse.snapped(190) == 185)   // 45 + 7 × 20 = 185
    }

    @Test func everyNamedBarKnowsBothUnits() {
        let olympic = PlateSet.bars.first { $0.name == "Olympic" }

        #expect(olympic?.weight(in: .imperial) == 45)
        #expect(olympic?.weight(in: .metric) == 20)
        #expect(PlateSet.pounds.namedBar?.name == "Olympic")
        #expect(PlateSet.kilograms.namedBar?.name == "Olympic")
    }

    /// Twelve of the heaviest plate on each side — the most either rack will
    /// be asked to build.
    /// Twelve of the same plate is a wall of one number; the count is what
    /// you are actually going to do.
    @Test func repeatsAreCounted() {
        #expect(PlateMath.load(target: 1125, using: .pounds).grouped == "45 ×12")
        #expect(PlateMath.load(target: 225, using: .pounds).grouped == "45 ×2")
        #expect(PlateMath.load(target: 185, using: .pounds).grouped == "45 · 25")
        #expect(PlateMath.load(target: 290, using: .pounds).grouped == "45 ×2 · 25 · 5 · 2.5")
        #expect(PlateMath.load(target: 45, using: .pounds).grouped == "")
    }

    @Test func theCeilingIsTwelvePlatesASide() {
        #expect(PlateSet.pounds.maxWeight == 45 + 45 * 24)        // 1,125 lb
        #expect(PlateSet.kilograms.maxWeight == 20 + 25 * 24)     // 620 kg
    }

    @Test func snappingNeverExceedsTheCeiling() {
        #expect(PlateSet.pounds.snapped(22_500) == 1125)
        #expect(PlateSet.kilograms.snapped(10_000) == 620)
    }

    /// A gym with lighter plates has a lower ceiling, which is the point of
    /// hanging it off the heaviest one on the rack.
    @Test func aLighterRackHasALowerCeiling() {
        let light = PlateSet(unit: .imperial, bar: 45, plates: [25, 10, 5])

        #expect(light.maxWeight == 45 + 25 * 24)
    }

    @Test func aPlateSetIsSortedHeaviestFirstHoweverItIsGiven() {
        let set = PlateSet(unit: .imperial, bar: 45, plates: [10, 45, 2.5, 25])

        #expect(set.plates == [45, 25, 10, 2.5])
    }
}
