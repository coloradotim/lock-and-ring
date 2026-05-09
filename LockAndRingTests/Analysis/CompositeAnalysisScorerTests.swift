@testable import LockAndRing
import XCTest

final class CompositeAnalysisScorerTests: XCTestCase {
    private let generator = SyntheticAudioGenerator(duration: 0.35)

    func testCompositeProducesAllFourMetricSnapshots() throws {
        var scorer = makeCompositeScorer()
        let frame = try frame(samples: generator.reinforcedHarmonicStack())

        _ = scorer.score(frame: frame)
        let result = scorer.score(frame: frame)

        XCTAssertEqual(result.meters.lock.kind, .lock)
        XCTAssertEqual(result.meters.ring.kind, .ring)
        XCTAssertEqual(result.meters.roughness.kind, .roughness)
        XCTAssertEqual(result.meters.stability.kind, .stability)
        XCTAssertNotNil(result.meters.lock.rawMeasurements["harmonicFit"])
        XCTAssertNotNil(result.meters.ring.rawMeasurements["harmonicEnergyRatio"])
        XCTAssertNotNil(result.meters.roughness.rawMeasurements["rawPairInteraction"])
        XCTAssertNotNil(result.meters.stability.rawMeasurements["peakPersistence"])
    }

    func testLowSignalGatesConfidenceAcrossAllMetrics() throws {
        var scorer = makeCompositeScorer()
        let quietSamples = generator.reinforcedHarmonicStack().map { $0 * 0.002 }
        let result = scorer.score(frame: try frame(samples: quietSamples))
        let confidences = [
            result.meters.lock.confidence.value,
            result.meters.ring.confidence.value,
            result.meters.roughness.confidence.value,
            result.meters.stability.confidence.value
        ]

        XCTAssertEqual(result.signalQuality.state, .lowSignal)
        XCTAssertTrue(confidences.allSatisfy { $0 < 0.25 })
    }

    func testRoughnessKeepsRawRougherMeansHigherSemantics() throws {
        var smoothScorer = makeCompositeScorer()
        var roughScorer = makeCompositeScorer()

        _ = smoothScorer.score(frame: try frame(samples: generator.octave()))
        _ = roughScorer.score(frame: try frame(samples: generator.closeSemitoneCluster(root: 440)))
        let smooth = smoothScorer.score(frame: try frame(samples: generator.octave()))
        let rough = roughScorer.score(frame: try frame(samples: generator.closeSemitoneCluster(root: 440)))

        XCTAssertGreaterThan(rough.meters.roughness.score.value, smooth.meters.roughness.score.value)
    }

    private func makeCompositeScorer() -> CompositeAnalysisScorer {
        CompositeAnalysisScorer(
            spectrumAnalyzer: SpectrumAnalyzer(fftSize: 4_096, smoothingFactor: 1)
        )
    }

    private func frame(samples: [Float]) throws -> AudioInputFrame {
        try XCTUnwrap(
            AudioFrameNormalizer.makeFrame(channels: [samples], sampleRate: generator.sampleRate)
        )
    }
}
