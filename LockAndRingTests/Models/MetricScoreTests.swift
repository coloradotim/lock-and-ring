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

    func testMetricSnapshotPlaceholderIsLowConfidence() {
        let snapshot = MetricSnapshot.placeholder(kind: .ring)

        XCTAssertEqual(snapshot.kind, .ring)
        XCTAssertEqual(snapshot.score.value, 0)
        XCTAssertEqual(snapshot.confidence.value, 0)
        XCTAssertEqual(snapshot.signalQuality, .unavailable)
    }

    func testMetricSnapshotReplacementPreservesContractFields() {
        let snapshot = MetricSnapshot(
            kind: .roughness,
            score: MetricScore(value: 0.2),
            confidence: MetricConfidence(value: 0.8, reason: "fixture"),
            contributingFactors: [MetricFactor(name: "factor", value: 0.6)],
            rawMeasurements: ["raw": 1.2],
            signalQuality: .nominal,
            rollingAverage: MetricScore(value: 0.3)
        )

        let replaced = snapshot.replacingScore(0.9)

        XCTAssertEqual(replaced.score.value, 0.9)
        XCTAssertEqual(replaced.confidence, snapshot.confidence)
        XCTAssertEqual(replaced.contributingFactors, snapshot.contributingFactors)
        XCTAssertEqual(replaced.rawMeasurements, snapshot.rawMeasurements)
        XCTAssertEqual(replaced.signalQuality, snapshot.signalQuality)
        XCTAssertEqual(replaced.rollingAverage, snapshot.rollingAverage)
    }
}
