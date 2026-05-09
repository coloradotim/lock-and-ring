@testable import LockAndRing
import XCTest

final class AnalysisConfigurationTests: XCTestCase {
    func testDefaultConfigurationIsValid() {
        XCTAssertTrue(AnalysisConfiguration.default.isValid)
        XCTAssertEqual(AnalysisConfiguration.default.confidence.reliableAnalysis, 0.55)
        XCTAssertEqual(AnalysisConfiguration.default.chordTiming.lockScore, 0.65)
        XCTAssertEqual(AnalysisConfiguration.default.comparison.stableFrameScore, 0.65)
    }

    func testChordTimingUsesInjectedThresholds() {
        let frames = [
            frame(time: 0, confidence: 0.7, lock: 0.5, roughness: 0.2, stability: 0.7),
            frame(time: 0.1, confidence: 0.7, lock: 0.56, roughness: 0.2, stability: 0.7)
        ]
        let permissive = ChordLabAnalyzer(
            thresholds: ChordLabThresholds(minimumSustainedDuration: 0.1, lockScore: 0.55)
        )
        let conservative = ChordLabAnalyzer(
            thresholds: ChordLabThresholds(minimumSustainedDuration: 0.1, lockScore: 0.75)
        )

        XCTAssertTrue(permissive.analyze(frames: frames).summary.didLock)
        XCTAssertFalse(conservative.analyze(frames: frames).summary.didLock)
    }

    func testConfidenceDisplayUsesInjectedThresholds() {
        let meters = MeterSnapshot(
            lock: snapshot(kind: .lock, confidence: 0.6),
            ring: snapshot(kind: .ring, confidence: 0.6),
            roughness: snapshot(kind: .roughness, confidence: 0.6),
            stability: snapshot(kind: .stability, confidence: 0.6)
        )

        XCTAssertEqual(AnalysisConfidenceState(meters: meters), .reliable)
        XCTAssertEqual(
            AnalysisConfidenceState(
                meters: meters,
                thresholds: ConfidenceThresholds(reliableAnalysis: 0.7)
            ),
            .lowConfidence(reason: .insufficientAnalyzableAudio)
        )
    }

    private func frame(
        time: TimeInterval,
        confidence: Double,
        lock: Double,
        roughness: Double,
        stability: Double
    ) -> AnalysisFrame {
        AnalysisFrame(
            timestamp: Date(timeIntervalSince1970: time),
            meters: MeterSnapshot(
                lock: snapshot(kind: .lock, score: lock, confidence: confidence),
                ring: snapshot(kind: .ring, score: 0.2, confidence: confidence),
                roughness: snapshot(kind: .roughness, score: roughness, confidence: confidence),
                stability: snapshot(kind: .stability, score: stability, confidence: confidence)
            ),
            spectrum: .placeholder,
            spectrogram: .placeholder,
            ringHistory: .placeholder
        )
    }

    private func snapshot(
        kind: MetricKind,
        score: Double = 0.5,
        confidence: Double
    ) -> MetricSnapshot {
        MetricSnapshot(
            kind: kind,
            score: MetricScore(value: score),
            confidence: MetricConfidence(value: confidence, reason: "fixture"),
            signalQuality: .nominal
        )
    }
}
