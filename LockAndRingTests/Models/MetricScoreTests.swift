@testable import LockAndRing
import XCTest

final class MetricScoreTests: XCTestCase {
    func testScoreClampsBelowZero() {
        XCTAssertEqual(MetricScore(value: -0.25).value, 0)
    }

    func testScoreKeepsInRangeValue() {
        XCTAssertEqual(MetricScore(value: 0.42).value, 0.42)
    }

    func testScoreClampsAboveOne() {
        XCTAssertEqual(MetricScore(value: 1.25).value, 1)
    }
}
