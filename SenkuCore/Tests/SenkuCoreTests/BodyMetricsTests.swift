import Testing
@testable import SenkuCore

@Suite("Body metrics")
struct BodyMetricsTests {
    @Test("Imperial input describes the same person as metric")
    func imperialInputConvertsToSamePersonAsMetric() throws {
        // 5'10", 180 lb -> 177.8 cm, 81.65 kg
        let imperial = try BodyMetrics(sex: .male, age: 30, feet: 5, inches: 10, pounds: 180)
        expectClose(imperial.heightCM, 177.8)
        expectClose(imperial.weightKG, 81.647)
    }

    @Test("BMI matches the textbook definition")
    func bmiMatchesTextbookDefinition() throws {
        let metrics = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 81)
        expectClose(metrics.bmi, 25.0)
    }

    @Test("Lean and fat mass sum back to bodyweight")
    func leanAndFatMassSumBackToBodyweight() throws {
        let metrics = try BodyMetrics(
            sex: .female, age: 28, heightCM: 165, weightKG: 60, bodyFatPercentage: 25
        )
        expectClose(metrics.leanBodyMassKG, 45, tolerance: 0.001)
        expectClose(metrics.leanBodyMassKG + metrics.fatMassKG, 60, tolerance: 0.001)
    }

    @Test("Healthy weight range brackets current weight")
    func healthyWeightRangeBracketsCurrentWeight() throws {
        let metrics = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 75)
        let range = metrics.healthyWeightRangeKG
        #expect(range.contains(75))
        expectClose(range.lowerBound, 59.94, tolerance: 0.1)
        expectClose(range.upperBound, 80.68, tolerance: 0.1)
    }

    @Test("Impossible input is rejected rather than clamped")
    func outOfRangeInputsAreRejectedRatherThanClamped() {
        #expect(throws: ValidationError.ageOutOfRange(12)) {
            try BodyMetrics(sex: .male, age: 12, heightCM: 170, weightKG: 60)
        }
        #expect(throws: ValidationError.weightOutOfRange(10)) {
            try BodyMetrics(sex: .male, age: 30, heightCM: 170, weightKG: 10)
        }
        #expect(throws: ValidationError.heightOutOfRange(300)) {
            try BodyMetrics(sex: .male, age: 30, heightCM: 300, weightKG: 60)
        }
        #expect(throws: ValidationError.bodyFatOutOfRange(2)) {
            try BodyMetrics(sex: .male, age: 30, heightCM: 170, weightKG: 60, bodyFatPercentage: 2)
        }
    }
}
