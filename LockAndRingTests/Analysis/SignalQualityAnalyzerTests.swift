@testable import LockAndRing
import XCTest

final class SignalQualityAnalyzerTests: XCTestCase {
    func testClippingCapsConfidenceAndReportsClipping() {
        var analyzer = SignalQualityAnalyzer()
        let assessment = analyzer.analyze(
            frame: frame(samples: [0.1, -0.2, 0.99, -0.4], isClipping: true),
            spectrum: spectrum(root: 220)
        )

        XCTAssertEqual(assessment.state, .clipping)
        XCTAssertLessThanOrEqual(assessment.confidenceMultiplier, 0.2)
        XCTAssertEqual(assessment.displayText, "Input clipping")
    }

    func testLowSignalProducesLowConfidence() {
        var analyzer = SignalQualityAnalyzer()
        let assessment = analyzer.analyze(
            frame: frame(samples: [0.001, -0.001, 0.002, -0.002], hasSignal: false),
            spectrum: spectrum(root: 220)
        )

        XCTAssertEqual(assessment.state, .lowSignal)
        XCTAssertLessThan(assessment.confidenceMultiplier, 0.2)
    }

    func testNoisySignalDegradesConfidenceWithoutChangingScore() {
        let snapshot = MetricSnapshot(
            kind: .ring,
            score: MetricScore(value: 0.72),
            confidence: MetricConfidence(value: 0.9, reason: "fixture")
        )
        let assessment = SignalQualityAssessment(
            state: .noisy,
            confidenceMultiplier: 0.4,
            levelAdequacy: 1,
            signalToNoiseRatio: 0.2,
            spectralStability: 0.8,
            transientCleanliness: 0.8,
            reasons: ["Excessive background noise"]
        )

        let gated = snapshot.applyingSignalQuality(assessment)

        XCTAssertEqual(gated.score.value, 0.72)
        XCTAssertEqual(gated.confidence.value, 0.36, accuracy: 0.0001)
        XCTAssertEqual(gated.signalQuality, .noisy)
        XCTAssertEqual(gated.rawMeasurements["signalToNoiseRatio"], 0.2)
    }

    func testSpectralInstabilityReportsLowConfidenceCondition() {
        var analyzer = SignalQualityAnalyzer()

        _ = analyzer.analyze(frame: stableFrame(), spectrum: spectrum(root: 220))
        let assessment = analyzer.analyze(frame: stableFrame(), spectrum: spectrum(root: 410))

        XCTAssertEqual(assessment.state, .unstable)
        XCTAssertLessThan(assessment.spectralStability, 0.25)
    }

    func testStableMusicalInputCanRemainNominal() {
        var analyzer = SignalQualityAnalyzer()

        _ = analyzer.analyze(frame: stableFrame(), spectrum: spectrum(root: 220))
        let assessment = analyzer.analyze(frame: stableFrame(), spectrum: spectrum(root: 221))

        XCTAssertEqual(assessment.state, .nominal)
        XCTAssertGreaterThan(assessment.confidenceMultiplier, 0.55)
    }

    private func stableFrame() -> AudioInputFrame {
        let samples = (0..<512).map { index in
            Float(sin(Double(index) * 0.18) * 0.18)
        }

        return frame(samples: samples, noiseFloor: 0.002)
    }

    private func frame(
        samples: [Float],
        isClipping: Bool = false,
        hasSignal: Bool = true,
        noiseFloor: Float = 0.001
    ) -> AudioInputFrame {
        let rms = rootMeanSquare(samples)

        return AudioInputFrame(
            hostTime: 0,
            sampleRate: 44_100,
            frameSize: samples.count,
            channelCount: 1,
            monoSamples: samples,
            channelSamples: [samples],
            instrumentation: AudioInputInstrumentation(
                rmsLevel: rms,
                channelRMSLevels: [rms],
                isClipping: isClipping,
                channelClipping: [isClipping],
                hasChannelImbalance: false,
                noiseFloor: noiseFloor,
                hasSignal: hasSignal
            )
        )
    }

    private func rootMeanSquare(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else {
            return 0
        }

        let sum = samples.reduce(Float(0)) { result, sample in
            result + sample * sample
        }
        return sqrt(sum / Float(samples.count))
    }

    private func spectrum(root: Double) -> SpectrumSnapshot {
        let peaks = (1...5).map { harmonic in
            SpectrumPeak(
                frequency: root * Double(harmonic),
                magnitude: 1 / Double(harmonic),
                binIndex: harmonic
            )
        }

        return SpectrumSnapshot(sampleRate: 44_100, fftSize: 2_048, bins: [], peaks: peaks)
    }
}
