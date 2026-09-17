import Testing
import Foundation
@testable import SenkuCore

/// Weight history is mostly noise with a signal underneath, so these tests are
/// about what the app refuses to conclude as much as what it concludes.
@Suite("Weight series")
struct WeightSeriesTests {
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ n: Int) -> Date {
        start.addingTimeInterval(Double(n) * 86_400)
    }

    private func series(_ readings: [(Int, Double)]) throws -> WeightSeries {
        WeightSeries(try readings.map { try WeighIn(date: day($0.0), weightKG: $0.1) })
    }

    // MARK: - Trend

    @Test("An empty history has nothing to say")
    func emptyHistoryHasNothingToSay() {
        let empty = WeightSeries([])
        #expect(empty.isEmpty)
        #expect(empty.trendKG == nil)
        #expect(empty.weeklyChangeKG == nil)
        #expect(empty.latest == nil)
    }

    @Test("The trend lags a jump rather than following it")
    func trendLagsAJumpRatherThanFollowingIt() throws {
        // Steady at 80, then one day two kilos up — a big meal, not two kilos
        // of tissue. The scale says 82; the trend must not.
        let s = try series([(0, 80), (1, 80), (2, 80), (3, 80), (4, 82)])

        let trend = try #require(s.trendKG)
        #expect(s.latest?.weightKG == 82)
        #expect(trend > 80)
        #expect(trend < 80.3)
    }

    @Test("A sustained change is followed within a couple of weeks")
    func sustainedChangeIsFollowed() throws {
        let readings = (0 ... 20).map { ($0, 80.0 - Double($0) * 0.1) }
        let s = try series(readings)

        let trend = try #require(s.trendKG)
        // Latest reading is 78.0. A smoothed line trails a steady slope by
        // roughly slope ÷ decay — about a kilo here — which is the cost of not
        // chasing noise, and is why the app shows both the readings and this.
        #expect(trend > 78.0)
        #expect(trend < 79.2)
    }

    @Test("A gap decays the old value rather than treating it as yesterday's")
    func gapDecaysTheOldValue() throws {
        let close = try series([(0, 80), (1, 76)])
        let distant = try series([(0, 80), (30, 76)])

        let closeTrend = try #require(close.trendKG)
        let distantTrend = try #require(distant.trendKG)

        // After a month away, the new reading should dominate; after a day, the
        // old one still counts for most of it.
        #expect(closeTrend > 79)
        #expect(distantTrend < 76.3)
    }

    @Test("Two weigh-ins on one day are averaged, not counted twice")
    func twoWeighInsOnOneDayAreAveraged() throws {
        // Anchored to the calendar's own day, so the test does not quietly
        // depend on where midnight falls for whoever is running it.
        let midnight = Calendar.current.startOfDay(for: day(0))
        let morning = try WeighIn(date: midnight.addingTimeInterval(8 * 3600), weightKG: 80)
        let evening = try WeighIn(date: midnight.addingTimeInterval(20 * 3600), weightKG: 82)
        let s = WeightSeries([morning, evening])

        #expect(s.dailyValues.count == 1)
        #expect(s.dailyValues[0].weightKG == 81)
    }

    // MARK: - Rate

    @Test("The weekly rate is measured across every reading, not the endpoints")
    func weeklyRateIgnoresEndpointNoise() throws {
        // A clean half-kilo a week, with the last day sabotaged by a heavy meal.
        var readings = (0 ... 14).map { ($0, 80.0 - Double($0) * 0.0714) }
        readings[14] = (14, 81.0)

        let weekly = try #require(try series(readings).weeklyChangeKG)

        // Endpoints alone would report a *gain*. A regression still sees the
        // fortnight of loss underneath.
        #expect(weekly < 0)
    }

    @Test("A single reading supports no rate at all")
    func singleReadingSupportsNoRate() throws {
        let s = try series([(0, 80)])
        #expect(s.trendKG == 80)
        #expect(s.weeklyChangeKG == nil)
    }

    // MARK: - Validation

    @Test("A weight outside the accepted range is refused")
    func weightOutsideRangeIsRefused() {
        #expect(throws: ValidationError.self) {
            _ = try WeighIn(date: Date(), weightKG: 4)
        }
    }
}

@Suite("Adaptive maintenance")
struct AdaptiveMaintenanceTests {
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func fortnight(changePerWeek: Double) throws -> WeightSeries {
        WeightSeries(
            try (0 ... 14).map {
                try WeighIn(
                    date: start.addingTimeInterval(Double($0) * 86_400),
                    weightKG: 80 + changePerWeek * Double($0) / 7
                )
            }
        )
    }

    private func plan() throws -> NutritionPlan {
        let metrics = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 80)
        return NutritionPlan.make(for: metrics, activityLevel: .moderate, goal: .maintain)
    }

    @Test("Losing weight on a known intake implies a higher maintenance")
    func lossImpliesHigherMaintenance() throws {
        let estimate = try #require(
            AdaptiveMaintenance.estimate(
                from: try fortnight(changePerWeek: -0.5),
                intakeCalories: 2200,
                plan: try plan()
            )
        )

        // Half a kilo a week is about 550 kcal/day, so maintenance is about
        // 2,750 — whatever the formula happened to say.
        #expect(estimate.estimatedMaintenance > 2700)
        #expect(estimate.estimatedMaintenance < 2800)
        #expect(estimate.dailyDelta < 0)
    }

    @Test("Holding weight implies maintenance is whatever you were eating")
    func holdingWeightImpliesIntakeIsMaintenance() throws {
        let estimate = try #require(
            AdaptiveMaintenance.estimate(
                from: try fortnight(changePerWeek: 0),
                intakeCalories: 2500,
                plan: try plan()
            )
        )

        #expect(abs(estimate.estimatedMaintenance - 2500) < 1)
    }

    @Test("Too little history produces no estimate rather than a bad one")
    func tooLittleHistoryProducesNoEstimate() throws {
        let week = WeightSeries(
            try (0 ... 6).map {
                try WeighIn(date: start.addingTimeInterval(Double($0) * 86_400), weightKG: 80)
            }
        )

        #expect(
            AdaptiveMaintenance.estimate(from: week, intakeCalories: 2500, plan: try plan()) == nil
        )
    }

    @Test("A difference inside the noise is not worth acting on")
    func smallDifferenceIsNotWorthActingOn() {
        let barely = AdaptiveMaintenance(
            intakeCalories: 2500,
            observedWeeklyChangeKG: -0.05,
            formulaMaintenance: 2540
        )
        #expect(!barely.isWorthActingOn)

        let real = AdaptiveMaintenance(
            intakeCalories: 2500,
            observedWeeklyChangeKG: -0.5,
            formulaMaintenance: 2540
        )
        #expect(real.isWorthActingOn)
    }
}
