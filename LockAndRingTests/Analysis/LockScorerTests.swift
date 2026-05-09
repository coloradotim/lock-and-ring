@testable import LockAndRing
import XCTest

final class LockScorerTests: XCTestCase {
    private let scorer = LockScorer()

    func testJustMajorTriadScoresHigherThanCloseCluster() {
        let just = score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1),
                SpectralPartial(frequency: 275, magnitude: 0.75),
                SpectralPartial(frequency: 330, magnitude: 0.72),
                SpectralPartial(frequency: 440, magnitude: 0.45),
                SpectralPartial(frequency: 550, magnitude: 0.32)
            ]
        )
        let cluster = score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1),
                SpectralPartial(frequency: 233.1, magnitude: 0.8),
                SpectralPartial(frequency: 246.9, magnitude: 0.72),
                SpectralPartial(frequency: 440, magnitude: 0.35)
            ]
        )

        XCTAssertGreaterThan(just.value, cluster.value)
        XCTAssertGreaterThan(just.simpleRatioFit, cluster.simpleRatioFit)
    }

    func testJustMajorThirdScoresAtLeastEqualTemperedThird() {
        let just = score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1),
                SpectralPartial(frequency: 275, magnitude: 0.8),
                SpectralPartial(frequency: 440, magnitude: 0.45)
            ]
        )
        let equalTempered = score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1),
                SpectralPartial(frequency: 220 * pow(2, 4.0 / 12.0), magnitude: 0.8),
                SpectralPartial(frequency: 440, magnitude: 0.45)
            ]
        )

        XCTAssertGreaterThanOrEqual(just.value, equalTempered.value)
        XCTAssertGreaterThanOrEqual(just.simpleRatioFit, equalTempered.simpleRatioFit)
    }

    func testStableDetunedChordCanStayStableWhileLockDrops() {
        let stableDetuned = StabilityScore(
            value: 0.82,
            confidence: 0.8,
            peakDriftCents: 8,
            peakPersistence: 0.9,
            energyChange: 0.04,
            peaksUsed: 4
        )
        let just = score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1),
                SpectralPartial(frequency: 275, magnitude: 0.76),
                SpectralPartial(frequency: 330, magnitude: 0.72),
                SpectralPartial(frequency: 440, magnitude: 0.45)
            ],
            stability: stableDetuned
        )
        let detuned = score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1),
                SpectralPartial(frequency: 278, magnitude: 0.76),
                SpectralPartial(frequency: 337, magnitude: 0.72),
                SpectralPartial(frequency: 440, magnitude: 0.45)
            ],
            stability: stableDetuned
        )

        XCTAssertGreaterThan(stableDetuned.value, 0.75)
        XCTAssertLessThan(detuned.value, just.value)
    }

    func testMetricSnapshotExportsRawComponents() {
        let score = score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1),
                SpectralPartial(frequency: 275, magnitude: 0.75),
                SpectralPartial(frequency: 330, magnitude: 0.72)
            ]
        )
        let snapshot = score.metricSnapshot()

        XCTAssertEqual(snapshot.kind, .lock)
        XCTAssertEqual(snapshot.score.value, score.value)
        XCTAssertEqual(snapshot.rawMeasurements["harmonicFit"], score.harmonicFit)
        XCTAssertEqual(snapshot.rawMeasurements["simpleRatioFit"], score.simpleRatioFit)
        XCTAssertEqual(snapshot.rawMeasurements["roughnessPenalty"], score.roughnessPenalty)
        XCTAssertEqual(snapshot.rawMeasurements["stabilityContribution"], score.stabilityContribution)
    }

    private func score(
        partials: [SpectralPartial],
        stability: StabilityScore = StabilityScore(
            value: 0.86,
            confidence: 0.82,
            peakDriftCents: 4,
            peakPersistence: 0.92,
            energyChange: 0.03,
            peaksUsed: 4
        )
    ) -> LockScore {
        let roughness = RoughnessScorer().score(partials: partials)
        return scorer.score(partials: partials, roughness: roughness, stability: stability)
    }
}
