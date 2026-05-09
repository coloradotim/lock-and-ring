@testable import LockAndRing
import XCTest

@MainActor
final class TakeComparisonTests: XCTestCase {
    func testRecorderStoresFramesForSelectedTake() {
        let recorder = TakeRecorder()
        let start = Date(timeIntervalSince1970: 10)

        recorder.startRecording(slot: .takeA, now: start)
        recorder.record(frame(lock: 0.2, ring: 0.3, roughness: 0.7, stability: 0.8))
        recorder.record(frame(lock: 0.4, ring: 0.5, roughness: 0.4, stability: 0.6))
        recorder.finishRecording(now: start.addingTimeInterval(3))

        XCTAssertNil(recorder.activeSlot)
        XCTAssertEqual(recorder.takeA?.slot, .takeA)
        XCTAssertEqual(recorder.takeA?.name, "Before adjustment")
        XCTAssertEqual(recorder.takeA?.frames.count, 2)
        XCTAssertEqual(recorder.takeA?.duration, 3)
    }

    func testComparisonRequiresBothTakes() {
        let recorder = TakeRecorder()
        let start = Date(timeIntervalSince1970: 20)

        recorder.startRecording(slot: .takeA, now: start)
        recorder.record(frame(lock: 0.4, ring: 0.4, roughness: 0.4, stability: 0.4))
        recorder.finishRecording(now: start.addingTimeInterval(1))

        XCTAssertNil(recorder.comparison)
    }

    func testComparisonMarksRoughnessDecreaseAsImprovement() {
        let comparison = TakeComparisonSummary(
            takeA: take(
                slot: .takeA,
                duration: 2,
                frames: [
                    frame(lock: 0.4, ring: 0.3, roughness: 0.7, stability: 0.4),
                    frame(lock: 0.5, ring: 0.4, roughness: 0.5, stability: 0.7)
                ]
            ),
            takeB: take(
                slot: .takeB,
                duration: 2,
                frames: [
                    frame(lock: 0.6, ring: 0.7, roughness: 0.3, stability: 0.9),
                    frame(lock: 0.7, ring: 0.8, roughness: 0.2, stability: 0.8)
                ]
            )
        )

        XCTAssertEqual(comparison.lock.delta, 0.2, accuracy: 0.0001)
        XCTAssertEqual(comparison.roughness.delta, -0.35, accuracy: 0.0001)
        XCTAssertTrue(comparison.lock.isImproved)
        XCTAssertTrue(comparison.roughness.isImproved)
        XCTAssertTrue(comparison.ring.isImproved)
        XCTAssertTrue(comparison.stabilityDuration.isImproved)
        XCTAssertEqual(comparison.headline, "Take 2 improved")
    }

    func testComparisonMarksDirectionalRegression() {
        let comparison = TakeComparisonSummary(
            takeA: take(
                slot: .takeA,
                duration: 1,
                frames: [frame(lock: 0.8, ring: 0.8, roughness: 0.2, stability: 0.8)]
            ),
            takeB: take(
                slot: .takeB,
                duration: 1,
                frames: [frame(lock: 0.5, ring: 0.3, roughness: 0.6, stability: 0.3)]
            )
        )

        XCTAssertTrue(comparison.lock.isRegressed)
        XCTAssertTrue(comparison.roughness.isRegressed)
        XCTAssertTrue(comparison.ring.isRegressed)
        XCTAssertTrue(comparison.stabilityDuration.isRegressed)
        XCTAssertEqual(comparison.headline, "Take 2 moved away")
    }

    func testStableDurationCountsFramesAboveThreshold() {
        let summary = take(
            slot: .takeA,
            duration: 4,
            frames: [
                frame(lock: 0, ring: 0, roughness: 0, stability: 0.7),
                frame(lock: 0, ring: 0, roughness: 0, stability: 0.8),
                frame(lock: 0, ring: 0, roughness: 0, stability: 0.3),
                frame(lock: 0, ring: 0, roughness: 0, stability: 0.2)
            ]
        ).summary

        XCTAssertEqual(summary.stabilityDuration, 2, accuracy: 0.0001)
    }

    private func take(
        slot: TakeSlot,
        duration: TimeInterval,
        frames: [AnalysisFrame]
    ) -> RecordedTake {
        let start = Date(timeIntervalSince1970: 100)

        return RecordedTake(
            slot: slot,
            name: slot.defaultName,
            startedAt: start,
            endedAt: start.addingTimeInterval(duration),
            frames: frames
        )
    }

    private func frame(
        lock: Double,
        ring: Double,
        roughness: Double,
        stability: Double
    ) -> AnalysisFrame {
        AnalysisFrame.placeholder.replacingMeters(
            MeterSnapshot(
                lock: snapshot(kind: .lock, score: lock),
                ring: snapshot(kind: .ring, score: ring),
                roughness: snapshot(kind: .roughness, score: roughness),
                stability: snapshot(kind: .stability, score: stability)
            )
        )
    }

    private func snapshot(kind: MetricKind, score: Double) -> MetricSnapshot {
        MetricSnapshot(
            kind: kind,
            score: MetricScore(value: score),
            confidence: MetricConfidence(value: 1, reason: "fixture")
        )
    }
}

private extension AnalysisFrame {
    func replacingMeters(_ meters: MeterSnapshot) -> AnalysisFrame {
        AnalysisFrame(
            timestamp: timestamp,
            meters: meters,
            spectrum: spectrum,
            spectrogram: spectrogram,
            ringHistory: ringHistory
        )
    }
}
