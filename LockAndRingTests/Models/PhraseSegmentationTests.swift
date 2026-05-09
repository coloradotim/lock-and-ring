@testable import LockAndRing
import XCTest

final class PhraseSegmentationTests: XCTestCase {
    func testSegmentsExpectedPhraseRegionsAndComputesRatios() {
        let analysis = PhraseSegmenter().analyze(frames: [
            frame(time: 0.0, confidence: 0.05, signalQuality: .unavailable),
            frame(time: 0.1, confidence: 0.2),
            frame(time: 0.2, confidence: 0.7, lock: 0.2, ring: 0.1, roughness: 0.8, stability: 0.2),
            frame(time: 0.3, confidence: 0.7, lock: 0.2, ring: 0.1, roughness: 0.8, stability: 0.2),
            frame(time: 0.4, confidence: 0.7, lock: 0.2, ring: 0.1, roughness: 0.8, stability: 0.2),
            frame(time: 0.5, confidence: 0.7, lock: 0.2, ring: 0.1, roughness: 0.8, stability: 0.2),
            frame(time: 0.6, confidence: 0.7, lock: 0.2, ring: 0.1, roughness: 0.4, stability: 0.65),
            frame(time: 0.7, confidence: 0.7, lock: 0.7, ring: 0.2, roughness: 0.3, stability: 0.7),
            frame(time: 0.8, confidence: 0.7, lock: 0.7, ring: 0.5, roughness: 0.3, stability: 0.7),
            frame(time: 0.9, confidence: 0.2, signalQuality: .lowSignal)
        ])

        XCTAssertEqual(analysis.timelineSegments.map(\.kind), [
            .silenceOrBreath,
            .lowConfidence,
            .transition,
            .tuningOrSearching,
            .stableButNotRinging,
            .locked,
            .ringing,
            .lowConfidence
        ])
        XCTAssertEqual(analysis.summary.silenceBreathTime, 0.1, accuracy: 0.001)
        XCTAssertEqual(analysis.summary.lowConfidenceTime, 0.2, accuracy: 0.001)
        XCTAssertEqual(analysis.summary.consonantOnsetTime, 0, accuracy: 0.001)
        XCTAssertEqual(analysis.summary.analyzableVowelTime, 0.7, accuracy: 0.001)
        XCTAssertEqual(analysis.summary.lockedVowelTime, 0.1, accuracy: 0.001)
        XCTAssertEqual(analysis.summary.ringingVowelTime, 0.1, accuracy: 0.001)
        XCTAssertEqual(analysis.summary.lockedVowelRatio, 1.0 / 7.0, accuracy: 0.001)
        XCTAssertEqual(analysis.summary.ringingVowelRatio, 1.0 / 7.0, accuracy: 0.001)
    }

    func testTimelineSegmentsAreChronologicalWithoutGaps() {
        let analysis = PhraseSegmenter().analyze(frames: [
            frame(time: 0.0, confidence: 0.05, signalQuality: .unavailable),
            frame(time: 0.1, confidence: 0.7, lock: 0.2, roughness: 0.8, stability: 0.2),
            frame(time: 0.2, confidence: 0.7, lock: 0.7, roughness: 0.2, stability: 0.8)
        ])
        let segments = analysis.timelineSegments

        XCTAssertEqual(segments.map(\.startTime), segments.map(\.startTime).sorted())
        for pair in zip(segments, segments.dropFirst()) {
            XCTAssertEqual(pair.0.endTime, pair.1.startTime, accuracy: 0.001)
        }
    }

    private func frame(
        time: TimeInterval,
        confidence: Double,
        lock: Double = 0.2,
        ring: Double = 0.1,
        roughness: Double = 0.2,
        stability: Double = 0.7,
        signalQuality: SignalQualityState = .nominal
    ) -> AnalysisFrame {
        AnalysisFrame(
            timestamp: Date(timeIntervalSince1970: time),
            meters: MeterSnapshot(
                lock: snapshot(kind: .lock, score: lock, confidence: confidence, signalQuality: signalQuality),
                ring: snapshot(kind: .ring, score: ring, confidence: confidence, signalQuality: signalQuality),
                roughness: snapshot(
                    kind: .roughness,
                    score: roughness,
                    confidence: confidence,
                    signalQuality: signalQuality
                ),
                stability: snapshot(
                    kind: .stability,
                    score: stability,
                    confidence: confidence,
                    signalQuality: signalQuality
                )
            ),
            spectrum: .placeholder,
            spectrogram: .placeholder,
            ringHistory: .placeholder
        )
    }

    private func snapshot(
        kind: MetricKind,
        score: Double,
        confidence: Double,
        signalQuality: SignalQualityState
    ) -> MetricSnapshot {
        MetricSnapshot(
            kind: kind,
            score: MetricScore(value: score),
            confidence: MetricConfidence(value: confidence, reason: "fixture"),
            signalQuality: signalQuality
        )
    }
}
