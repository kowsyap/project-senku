import XCTest
@testable import SenkuUI

final class NumericFieldTests: XCTestCase {
    private let weightRange: ClosedRange<Double> = 35...200

    func testPlainNumbersParse() {
        XCTAssertEqual(NumericField.parse("82", into: weightRange), 82)
        XCTAssertEqual(NumericField.parse("82.5", into: weightRange), 82.5)
    }

    func testCommaIsAcceptedAsADecimalSeparator() {
        // Much of the world types this, and the number pad offers whichever
        // separator the locale prefers.
        XCTAssertEqual(NumericField.parse("82,5", into: weightRange), 82.5)
    }

    func testSurroundingWhitespaceIsIgnored() {
        XCTAssertEqual(NumericField.parse("  75 ", into: weightRange), 75)
    }

    func testOutOfRangeValuesAreClampedRatherThanRejected() {
        XCTAssertEqual(NumericField.parse("500", into: weightRange), 200)
        XCTAssertEqual(NumericField.parse("2", into: weightRange), 35)
        XCTAssertEqual(NumericField.parse("-40", into: weightRange), 35)
    }

    func testNonNumbersReturnNilSoTheFieldCanRevert() {
        // Reverting matters: zeroing the field on a typo would quietly change
        // someone's plan.
        XCTAssertNil(NumericField.parse("", into: weightRange))
        XCTAssertNil(NumericField.parse("abc", into: weightRange))
        XCTAssertNil(NumericField.parse("7.5.3", into: weightRange))
        XCTAssertNil(NumericField.parse("inf", into: weightRange))
        XCTAssertNil(NumericField.parse("nan", into: weightRange))
    }

    func testBoundariesAreInclusive() {
        XCTAssertEqual(NumericField.parse("35", into: weightRange), 35)
        XCTAssertEqual(NumericField.parse("200", into: weightRange), 200)
    }
}
