@testable import LockAndRing
import XCTest

final class MetricLabelValidationTests: XCTestCase {
    private let generator = SyntheticAudioGenerator(duration: 0.35)

    func testSyntheticHarmonicSignalLabelsBetterThanCloseCluster() throws {
        var harmonicScorer = makeScorer()
        var clusterScorer = makeScorer()

        _ = harmonicScorer.score(frame: try frame(samples: generator.reinforcedHarmonicStack()))
        _ = clusterScorer.score(frame: try frame(samples: generator.closeSemitoneCluster(root: 440)))
        let harmonic = harmonicScorer.score(frame: try frame(samples: generator.reinforcedHarmonicStack()))
        let cluster = clusterScorer.score(frame: try frame(samples: generator.closeSemitoneCluster(root: 440)))

        XCTAssertGreaterThan(scoreLabelRank(harmonic.meters.lock), scoreLabelRank(cluster.meters.lock))
    }

    func testSyntheticBeatingPartialsLabelRougherThanHarmonicPartials() {
        let smooth = RoughnessScorer().score(
            partials: [
                SpectralPartial(frequency: 220, magnitude: 1),
                SpectralPartial(frequency: 440, magnitude: 0.6),
                SpectralPartial(frequency: 660, magnitude: 0.45)
            ]
        )
        let rough = RoughnessScorer().score(
            partials: [
                SpectralPartial(frequency: 440, magnitude: 1),
                SpectralPartial(frequency: 444, magnitude: 0.98),
                SpectralPartial(frequency: 448, magnitude: 0.94),
                SpectralPartial(frequency: 452, magnitude: 0.9),
                SpectralPartial(frequency: 660, magnitude: 0.7),
                SpectralPartial(frequency: 666, magnitude: 0.66),
                SpectralPartial(frequency: 672, magnitude: 0.6)
            ]
        )

        XCTAssertLessThan(scoreLabelRank(smooth.metricSnapshot()), scoreLabelRank(rough.metricSnapshot()))
    }

    func testSyntheticReinforcedUpperPartialsLabelRingierThanChaoticPartials() throws {
        var reinforcedScorer = makeScorer()
        var chaoticScorer = makeScorer()

        _ = reinforcedScorer.score(frame: try frame(samples: generator.reinforcedHarmonicStack()))
        _ = chaoticScorer.score(frame: try frame(samples: generator.chaoticUpperPartials()))
        let reinforced = reinforcedScorer.score(frame: try frame(samples: generator.reinforcedHarmonicStack()))
        let chaotic = chaoticScorer.score(frame: try frame(samples: generator.chaoticUpperPartials()))

        XCTAssertGreaterThan(scoreLabelRank(reinforced.meters.ring), scoreLabelRank(chaotic.meters.ring))
    }

    func testLowConfidenceSignalSuppressesAuthoritativeLabels() throws {
        var scorer = makeScorer()
        let quietSamples = generator.reinforcedHarmonicStack().map { $0 * 0.002 }
        let result = scorer.score(frame: try frame(samples: quietSamples))
        let labels = [
            MetricDisplayState(snapshot: result.meters.lock).qualityLabel,
            MetricDisplayState(snapshot: result.meters.ring).qualityLabel,
            MetricDisplayState(snapshot: result.meters.roughness).qualityLabel,
            MetricDisplayState(snapshot: result.meters.stability).qualityLabel
        ]

        XCTAssertTrue(labels.allSatisfy { $0 == "Low confidence" || $0 == "Signal too quiet" })
    }

    private func labelRank(_ snapshot: MetricSnapshot) -> Int {
        let label = MetricDisplayState(snapshot: snapshot).qualityLabel
        let labels = MetricLabelDefinitions.bands(for: snapshot.kind).map(\.label)

        return labels.firstIndex(of: label) ?? -1
    }

    private func scoreLabelRank(_ snapshot: MetricSnapshot) -> Int {
        labelRank(
            MetricSnapshot(
                kind: snapshot.kind,
                score: snapshot.score,
                confidence: MetricConfidence(value: 1),
                signalQuality: .nominal
            )
        )
    }

    private func makeScorer() -> CompositeAnalysisScorer {
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
