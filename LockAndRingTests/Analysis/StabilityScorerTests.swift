@testable import LockAndRing
import XCTest

final class StabilityScorerTests: XCTestCase {
    private let generator = SyntheticAudioGenerator(duration: 0.35)

    func testSteadyHarmonicStackScoresMoreStableThanVibrato() {
        let steady = scoreAcrossWindows(samples: generator.reinforcedHarmonicStack())
        let vibrato = scoreAcrossWindows(
            samples: generator.singleSine(
                frequency: 440,
                vibrato: Vibrato(depthCents: 45, rate: 5.5)
            )
        )

        XCTAssertGreaterThan(steady.value, vibrato.value)
    }

    func testStableDetunedChordCanHaveHighStability() {
        let detuned = scoreRepeated(samples: generator.mistunedMajorThird(detuningCents: 24))

        XCTAssertGreaterThan(detuned.value, 0.65)
        XCTAssertGreaterThan(detuned.confidence, 0.45)
    }

    func testNoisyChangingInputHasLowConfidence() {
        var scorer = StabilityScorer()
        let first = spectrum(samples: generator.noisyRoomLikeInput(root: 220))
        let second = spectrum(
            samples: SyntheticAudioGenerator(duration: 0.35, seed: 0xBADF00D)
                .noisyRoomLikeInput(root: 247)
        )

        _ = scorer.score(spectrum: first)
        let score = scorer.score(spectrum: second)

        XCTAssertLessThan(score.confidence, 0.65)
    }

    func testMetricSnapshotExportsRawComponents() {
        let score = scoreRepeated(samples: generator.reinforcedHarmonicStack())
        let snapshot = score.metricSnapshot()

        XCTAssertEqual(snapshot.kind, .stability)
        XCTAssertEqual(snapshot.rawMeasurements["peakDriftCents"], score.peakDriftCents)
        XCTAssertEqual(snapshot.rawMeasurements["peakPersistence"], score.peakPersistence)
        XCTAssertEqual(snapshot.rawMeasurements["energyChange"], score.energyChange)
    }

    private func scoreRepeated(samples: [Float]) -> StabilityScore {
        var scorer = StabilityScorer()
        let first = spectrum(samples: samples)
        let second = spectrum(samples: samples)

        _ = scorer.score(spectrum: first)
        return scorer.score(spectrum: second)
    }

    private func scoreAcrossWindows(samples: [Float]) -> StabilityScore {
        var scorer = StabilityScorer()
        let windowSize = 4_096
        let hopSize = 4_096
        let first = spectrum(samples: Array(samples[0..<windowSize]))
        let second = spectrum(samples: Array(samples[hopSize..<(hopSize + windowSize)]))

        _ = scorer.score(spectrum: first)
        return scorer.score(spectrum: second)
    }

    private func spectrum(samples: [Float]) -> SpectrumSnapshot {
        SpectrumAnalyzer(fftSize: 4_096, smoothingFactor: 1)
            .analyze(samples: samples, sampleRate: generator.sampleRate)
    }
}
