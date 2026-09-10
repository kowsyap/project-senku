import XCTest
@testable import SenkuCore

final class BodyMetricsTests: XCTestCase {
    func testImperialInputConvertsToSamePersonAsMetric() throws {
        // 5'10", 180 lb -> 177.8 cm, 81.65 kg
        let imperial = try BodyMetrics(sex: .male, age: 30, feet: 5, inches: 10, pounds: 180)
        XCTAssertEqual(imperial.heightCM, 177.8, accuracy: 0.01)
        XCTAssertEqual(imperial.weightKG, 81.647, accuracy: 0.01)
    }

    func testBMIMatchesTextbookDefinition() throws {
        let metrics = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 81)
        XCTAssertEqual(metrics.bmi, 25.0, accuracy: 0.01)
    }

    func testLeanAndFatMassSumBackToBodyweight() throws {
        let metrics = try BodyMetrics(
            sex: .female, age: 28, heightCM: 165, weightKG: 60, bodyFatPercentage: 25
        )
        XCTAssertEqual(metrics.leanBodyMassKG, 45, accuracy: 0.001)
        XCTAssertEqual(metrics.leanBodyMassKG + metrics.fatMassKG, 60, accuracy: 0.001)
    }

    func testHealthyWeightRangeBracketsCurrentWeight() throws {
        let metrics = try BodyMetrics(sex: .male, age: 30, heightCM: 180, weightKG: 75)
        let range = metrics.healthyWeightRangeKG
        XCTAssertTrue(range.contains(75))
        XCTAssertEqual(range.lowerBound, 59.94, accuracy: 0.1)
        XCTAssertEqual(range.upperBound, 80.68, accuracy: 0.1)
    }

    func testOutOfRangeInputsAreRejectedRatherThanClamped() {
        assertThrows(.ageOutOfRange(12)) {
            try BodyMetrics(sex: .male, age: 12, heightCM: 170, weightKG: 60)
        }
        assertThrows(.weightOutOfRange(10)) {
            try BodyMetrics(sex: .male, age: 30, heightCM: 170, weightKG: 10)
        }
        assertThrows(.heightOutOfRange(300)) {
            try BodyMetrics(sex: .male, age: 30, heightCM: 300, weightKG: 60)
        }
        assertThrows(.bodyFatOutOfRange(2)) {
            try BodyMetrics(sex: .male, age: 30, heightCM: 170, weightKG: 60, bodyFatPercentage: 2)
        }
    }

    private func assertThrows(
        _ expected: ValidationError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () throws -> BodyMetrics
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            XCTAssertEqual(error as? ValidationError, expected, file: file, line: line)
        }
    }
}
