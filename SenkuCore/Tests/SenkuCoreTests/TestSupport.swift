import Testing

/// Swift Testing has no accuracy-tolerant equality to replace
/// `XCTAssertEqual(_:_:accuracy:)`, and every formula in this package returns a
/// `Double`. Comparing those exactly would make the suite fail on the last bit
/// rather than on a real arithmetic mistake.
func expectClose(
    _ actual: Double,
    _ expected: Double,
    tolerance: Double = 0.01,
    _ note: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        abs(actual - expected) <= tolerance,
        note ?? "expected \(expected) ± \(tolerance), got \(actual)",
        sourceLocation: sourceLocation
    )
}
