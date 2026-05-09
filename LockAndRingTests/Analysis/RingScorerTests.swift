@testable import LockAndRing
import XCTest

final class RingScorerTests: XCTestCase {
    private let scorer = RingScorer()

    func testHarmonicReinforcementScoresHigherThanSparseFundamental() {
        let sparse = scorer.score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1),
                SpectralPartial(frequency: 710, magnitude: 0.12)
            ]
        )
        let reinforced = scorer.score(partials: reinforcedHarmonicStack(root: 220))

        XCTAssertGreaterThan(reinforced.value, sparse.value)
        XCTAssertGreaterThan(reinforced.confidence, sparse.confidence)
    }

    func testAlignedHarmonicsScoreHigherThanDetunedUpperPartials() {
        let aligned = scorer.score(partials: reinforcedHarmonicStack(root: 220))
        let detuned = scorer.score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1),
                SpectralPartial(frequency: 463, magnitude: 0.82),
                SpectralPartial(frequency: 683, magnitude: 0.74),
                SpectralPartial(frequency: 928, magnitude: 0.62)
            ]
        )

        XCTAssertGreaterThan(aligned.value, detuned.value)
        XCTAssertGreaterThan(aligned.matchedHarmonics, detuned.matchedHarmonics)
    }

    func testTrebleNoiseWithoutHarmonicAlignmentDoesNotLookLikeRing() {
        let trebleNoise = scorer.score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1),
                SpectralPartial(frequency: 1_175, magnitude: 0.95),
                SpectralPartial(frequency: 1_430, magnitude: 0.8),
                SpectralPartial(frequency: 1_790, magnitude: 0.72)
            ]
        )
        let reinforced = scorer.score(partials: reinforcedHarmonicStack(root: 220))

        XCTAssertLessThan(trebleNoise.value, reinforced.value)
    }

    func testSpectrumPeaksCanDriveRingScore() {
        let spectrum = SpectrumSnapshot(
            sampleRate: 44_100,
            fftSize: 2_048,
            bins: [],
            peaks: reinforcedHarmonicStack(root: 220).enumerated().map { index, partial in
                SpectrumPeak(
                    frequency: partial.frequency,
                    magnitude: partial.magnitude,
                    binIndex: index
                )
            }
        )

        let score = scorer.score(spectrum: spectrum)

        XCTAssertGreaterThan(score.value, 0.1)
        XCTAssertGreaterThanOrEqual(score.matchedHarmonics, 4)
    }

    func testNoReliableAnchorReturnsLowConfidence() {
        let score = scorer.score(
            partials: [
                SpectralPartial(frequency: 1_100, magnitude: 0.8),
                SpectralPartial(frequency: 1_350, magnitude: 0.75)
            ]
        )

        XCTAssertEqual(score.value, 0)
        XCTAssertEqual(score.confidence, 0)
    }

    private func reinforcedHarmonicStack(root: Double) -> [SpectralPartial] {
        [
            SpectralPartial(frequency: root, magnitude: 1),
            SpectralPartial(frequency: root * 2, magnitude: 0.88),
            SpectralPartial(frequency: root * 3, magnitude: 0.82),
            SpectralPartial(frequency: root * 4, magnitude: 0.72),
            SpectralPartial(frequency: root * 5, magnitude: 0.62),
            SpectralPartial(frequency: root * 6, magnitude: 0.5)
        ]
    }
}
