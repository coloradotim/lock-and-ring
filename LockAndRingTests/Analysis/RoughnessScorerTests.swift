@testable import LockAndRing
import XCTest

final class RoughnessScorerTests: XCTestCase {
    private let scorer = RoughnessScorer()

    func testOctaveScoresSmootherThanCloseSemitoneCluster() {
        let octave = scorer.score(partials: harmonicPair(root: 220, ratio: 2))
        let cluster = scorer.score(partials: harmonicPair(root: 220, ratio: semitoneRatio()))

        XCTAssertLessThan(octave.value, cluster.value)
    }

    func testFifthScoresSmootherThanMajorThird() {
        let fifth = scorer.score(partials: harmonicPair(root: 220, ratio: 3.0 / 2.0))
        let majorThird = scorer.score(partials: harmonicPair(root: 220, ratio: 5.0 / 4.0))

        XCTAssertLessThan(fifth.value, majorThird.value)
    }

    func testBeatingIntervalScoresRougherThanCleanFifth() {
        let cleanFifth = scorer.score(partials: harmonicPair(root: 220, ratio: 3.0 / 2.0))
        let beatingInterval = scorer.score(
            partials: [
                SpectralPartial(frequency: 440, magnitude: 1),
                SpectralPartial(frequency: 446, magnitude: 0.92),
                SpectralPartial(frequency: 660, magnitude: 0.55)
            ]
        )

        XCTAssertGreaterThan(beatingInterval.value, cleanFifth.value)
    }

    func testSpectrumPeaksCanDriveRoughnessScore() {
        let spectrum = SpectrumSnapshot(
            sampleRate: 44_100,
            fftSize: 2_048,
            bins: [],
            peaks: [
                SpectrumPeak(frequency: 440, magnitude: 1, binIndex: 20),
                SpectrumPeak(frequency: 446, magnitude: 0.9, binIndex: 21)
            ]
        )

        let score = scorer.score(spectrum: spectrum)

        XCTAssertGreaterThan(score.value, 0)
        XCTAssertEqual(score.partialsUsed, 2)
    }

    func testRoughnessScoreExportsMetricSnapshot() {
        let score = scorer.score(partials: harmonicPair(root: 220, ratio: semitoneRatio()))
        let snapshot = score.metricSnapshot(signalQuality: .nominal)

        XCTAssertEqual(snapshot.kind, .roughness)
        XCTAssertEqual(snapshot.score.value, score.value)
        XCTAssertGreaterThan(snapshot.confidence.value, 0)
        XCTAssertEqual(snapshot.signalQuality, .nominal)
        XCTAssertEqual(snapshot.rawMeasurements["partialsUsed"], Double(score.partialsUsed))
    }

    func testInsufficientPartialsScoreAsSmooth() {
        let score = scorer.score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1)
            ]
        )

        XCTAssertEqual(score.value, 0)
        XCTAssertEqual(score.partialsUsed, 1)
    }

    private func harmonicPair(root: Double, ratio: Double) -> [SpectralPartial] {
        [
            SpectralPartial(frequency: root, magnitude: 1),
            SpectralPartial(frequency: root * ratio, magnitude: 0.85),
            SpectralPartial(frequency: root * 2, magnitude: 0.45),
            SpectralPartial(frequency: root * ratio * 2, magnitude: 0.36)
        ]
    }

    private func semitoneRatio() -> Double {
        pow(2, 1.0 / 12.0)
    }
}
