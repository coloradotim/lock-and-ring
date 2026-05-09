@testable import LockAndRing
import XCTest

final class SyntheticDSPFixtureTests: XCTestCase {
    private let generator = SyntheticAudioGenerator(duration: 0.35)

    func testFFTUsesSyntheticSingleSineFixture() {
        let analyzer = SpectrumAnalyzer(fftSize: 4_096, smoothingFactor: 1)
        let spectrum = analyzer.analyze(samples: generator.singleSine(frequency: 440), sampleRate: 44_100)
        let strongestPeak = spectrum.peaks.max { $0.magnitude < $1.magnitude }

        XCTAssertEqual(strongestPeak?.frequency ?? 0, 440, accuracy: 20)
    }

    func testFFTUsesSyntheticDominantSeventhFixture() {
        let analyzer = SpectrumAnalyzer(fftSize: 4_096, smoothingFactor: 1)
        let spectrum = analyzer.analyze(
            samples: generator.dominantSeventhApproximation(root: 220),
            sampleRate: 44_100
        )
        let peakFrequencies = spectrum.peaks.map(\.frequency)

        XCTAssertTrue(peakFrequencies.contains { abs($0 - 220) < 20 })
        XCTAssertTrue(peakFrequencies.contains { abs($0 - 275) < 20 })
        XCTAssertTrue(peakFrequencies.contains { abs($0 - 330) < 20 })
    }

    func testGeneratedCloseClusterScoresRougherThanGeneratedOctave() {
        let roughnessScorer = RoughnessScorer()
        let octave = scoreRoughness(samples: generator.octave(), scorer: roughnessScorer)
        let cluster = scoreRoughness(samples: generator.closeSemitoneCluster(), scorer: roughnessScorer)

        XCTAssertGreaterThan(cluster.value, octave.value)
    }

    func testGeneratedReinforcedStackScoresRingierThanChaoticStack() {
        let ringScorer = RingScorer()
        let reinforced = scoreRing(samples: generator.reinforcedHarmonicStack(), scorer: ringScorer)
        let chaotic = scoreRing(samples: generator.chaoticUpperPartials(), scorer: ringScorer)

        XCTAssertGreaterThan(reinforced.value, chaotic.value)
        XCTAssertGreaterThan(reinforced.confidence, chaotic.confidence)
    }

    func testVibratoFixtureShowsMorePeakDriftThanSteadyTone() {
        let steady = generator.singleSine(frequency: 440)
        let vibrato = generator.singleSine(
            frequency: 440,
            vibrato: Vibrato(depthCents: 35, rate: 5.5)
        )

        XCTAssertGreaterThan(peakDrift(samples: vibrato), peakDrift(samples: steady))
    }

    private func scoreRoughness(samples: [Float], scorer: RoughnessScorer) -> RoughnessScore {
        let analyzer = SpectrumAnalyzer(fftSize: 4_096, smoothingFactor: 1)
        let spectrum = analyzer.analyze(samples: samples, sampleRate: 44_100)
        return scorer.score(spectrum: spectrum)
    }

    private func scoreRing(samples: [Float], scorer: RingScorer) -> RingScore {
        let analyzer = SpectrumAnalyzer(fftSize: 4_096, smoothingFactor: 1)
        let spectrum = analyzer.analyze(samples: samples, sampleRate: 44_100)
        return scorer.score(spectrum: spectrum)
    }

    private func peakDrift(samples: [Float]) -> Double {
        let windowSize = 2_048
        let hopSize = 1_024
        let analyzer = SpectrumAnalyzer(fftSize: windowSize, smoothingFactor: 1)
        let peakFrequencies = stride(from: 0, to: samples.count - windowSize, by: hopSize).compactMap { start in
            let window = Array(samples[start..<(start + windowSize)])
            return analyzer
                .analyze(samples: window, sampleRate: 44_100)
                .peaks
                .max { $0.magnitude < $1.magnitude }?
                .frequency
        }

        guard let first = peakFrequencies.first else {
            return 0
        }

        return peakFrequencies.reduce(0) { max($0, abs($1 - first)) }
    }
}
