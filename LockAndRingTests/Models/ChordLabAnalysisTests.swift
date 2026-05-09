@testable import LockAndRing
import XCTest

final class ChordLabAnalysisTests: XCTestCase {
    private let analyzer = ChordLabAnalyzer(
        thresholds: ChordLabThresholds(minimumSustainedDuration: 0.1)
    )

    func testDetectsSoundOnsetAfterSilence() throws {
        let analysis = analyzer.analyze(frames: [
            frame(time: 0, confidence: 0.05),
            frame(time: 0.1, confidence: 0.08),
            frame(time: 0.2, confidence: 0.25),
            frame(time: 0.3, confidence: 0.45)
        ])

        XCTAssertEqual(try XCTUnwrap(analysis.summary.soundOnsetTime), 0.2, accuracy: 0.001)
    }

    func testReportsConsonantDurationBeforeAnalyzableVowelStart() throws {
        let analysis = analyzer.analyze(frames: [
            frame(time: 0, confidence: 0.05),
            frame(time: 0.1, confidence: 0.2),
            frame(time: 0.2, confidence: 0.3),
            frame(time: 0.3, confidence: 0.65, stability: 0.3),
            frame(time: 0.4, confidence: 0.65, stability: 0.4)
        ])

        XCTAssertEqual(try XCTUnwrap(analysis.summary.soundOnsetTime), 0.1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(analysis.summary.analyzableVowelStartTime), 0.3, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(analysis.summary.consonantOnsetDuration), 0.2, accuracy: 0.001)
    }

    func testReportsTimeToLockAndRingSeparately() throws {
        let analysis = analyzer.analyze(frames: [
            frame(time: 0.0, confidence: 0.2),
            frame(time: 0.1, confidence: 0.65, lock: 0.2, ring: 0.1, roughness: 0.6, stability: 0.4),
            frame(time: 0.2, confidence: 0.75, lock: 0.45, ring: 0.2, roughness: 0.35, stability: 0.6),
            frame(time: 0.3, confidence: 0.8, lock: 0.8, ring: 0.35, roughness: 0.25, stability: 0.75),
            frame(time: 0.4, confidence: 0.8, lock: 0.82, ring: 0.4, roughness: 0.25, stability: 0.75),
            frame(time: 0.5, confidence: 0.8, lock: 0.84, ring: 0.65, roughness: 0.22, stability: 0.76),
            frame(time: 0.6, confidence: 0.8, lock: 0.84, ring: 0.67, roughness: 0.22, stability: 0.76)
        ])

        XCTAssertEqual(try XCTUnwrap(analysis.summary.timeFromVowelToLock), 0.2, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(analysis.summary.timeFromVowelToRing), 0.4, accuracy: 0.001)
        XCTAssertTrue(analysis.summary.didLock)
        XCTAssertTrue(analysis.summary.didRing)
    }

    func testReportsNeverLockedButStillTracksBestAttempts() throws {
        let analysis = analyzer.analyze(frames: [
            frame(time: 0, confidence: 0.7, lock: 0.3, ring: 0.2, roughness: 0.4, stability: 0.6),
            frame(time: 0.1, confidence: 0.7, lock: 0.61, ring: 0.38, roughness: 0.35, stability: 0.7),
            frame(time: 0.2, confidence: 0.7, lock: 0.55, ring: 0.42, roughness: 0.4, stability: 0.7)
        ])

        XCTAssertNil(analysis.summary.timeFromVowelToLock)
        XCTAssertFalse(analysis.summary.didLock)
        XCTAssertEqual(try XCTUnwrap(analysis.summary.bestLockScore), 0.61, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(analysis.summary.bestLockTime), 0.1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(analysis.summary.bestRingScore), 0.42, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(analysis.summary.bestRingTime), 0.2, accuracy: 0.001)
    }

    func testTimelineSegmentsAreChronological() {
        let analysis = analyzer.analyze(frames: [
            frame(time: 0, confidence: 0.05),
            frame(time: 0.1, confidence: 0.2),
            frame(time: 0.2, confidence: 0.7, lock: 0.4, ring: 0.2, roughness: 0.4, stability: 0.6),
            frame(time: 0.3, confidence: 0.7, lock: 0.8, ring: 0.2, roughness: 0.2, stability: 0.7),
            frame(time: 0.4, confidence: 0.7, lock: 0.8, ring: 0.65, roughness: 0.2, stability: 0.7)
        ])
        let starts = analysis.timelineSegments.map(\.startTime)

        XCTAssertEqual(starts, starts.sorted())
        XCTAssertEqual(analysis.timelineSegments.first?.kind, .silence)
        XCTAssertEqual(analysis.timelineSegments.last?.kind, .ringing)
    }

    func testLargestDelayContributorIsDeterministic() {
        let analysis = analyzer.analyze(frames: [
            frame(time: 0.0, confidence: 0.2),
            frame(time: 0.1, confidence: 0.2),
            frame(time: 0.2, confidence: 0.7, lock: 0.2, ring: 0.1, roughness: 0.5, stability: 0.4),
            frame(time: 0.3, confidence: 0.7, lock: 0.8, ring: 0.2, roughness: 0.2, stability: 0.7),
            frame(time: 0.4, confidence: 0.7, lock: 0.8, ring: 0.2, roughness: 0.2, stability: 0.7),
            frame(time: 0.5, confidence: 0.7, lock: 0.8, ring: 0.2, roughness: 0.2, stability: 0.7),
            frame(time: 0.6, confidence: 0.7, lock: 0.8, ring: 0.65, roughness: 0.2, stability: 0.7)
        ])

        XCTAssertEqual(analysis.summary.largestDelayContributor, .ring)
    }

    private func frame(
        time: TimeInterval,
        confidence: Double,
        lock: Double = 0,
        ring: Double = 0,
        roughness: Double = 0,
        stability: Double = 0
    ) -> AnalysisFrame {
        AnalysisFrame(
            timestamp: Date(timeIntervalSince1970: time),
            meters: MeterSnapshot(
                lock: snapshot(kind: .lock, score: lock, confidence: confidence),
                ring: snapshot(
                    kind: .ring,
                    score: ring,
                    confidence: confidence,
                    rawMeasurements: ["upperHarmonicEnergyProxy": ring]
                ),
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
        score: Double,
        confidence: Double,
        rawMeasurements: [String: Double] = [:]
    ) -> MetricSnapshot {
        MetricSnapshot(
            kind: kind,
            score: MetricScore(value: score),
            confidence: MetricConfidence(value: confidence, reason: "fixture"),
            rawMeasurements: rawMeasurements,
            signalQuality: confidence >= 0.35 ? .nominal : .lowSignal
        )
    }
}
