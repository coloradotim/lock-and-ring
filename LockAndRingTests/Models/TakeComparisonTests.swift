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

    func testRecorderStoresReplayableAudioForSelectedTake() {
        let recorder = TakeRecorder()
        let start = Date(timeIntervalSince1970: 10)

        recorder.startRecording(slot: .takeA, now: start)
        recorder.record(
            frame(lock: 0.2, ring: 0.3, roughness: 0.7, stability: 0.8),
            inputFrame: audioInputFrame(samples: [0, 0.1, 0.2])
        )
        recorder.record(
            frame(lock: 0.4, ring: 0.5, roughness: 0.4, stability: 0.6),
            inputFrame: audioInputFrame(samples: [0.1, 0, -0.1])
        )
        recorder.finishRecording(now: start.addingTimeInterval(3))

        XCTAssertEqual(recorder.takeA?.audioClip?.sampleRate, 44_100)
        XCTAssertEqual(recorder.takeA?.audioClip?.channelSamples.first?.count, 6)
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

    func testRecordedTakeAnalysisFrameFreezesAggregateMetrics() {
        let take = take(
            slot: .takeA,
            duration: 2,
            frames: [
                frame(lock: 0.2, ring: 0.4, roughness: 0.8, stability: 0.6),
                frame(lock: 0.6, ring: 0.8, roughness: 0.2, stability: 0.9)
            ]
        )

        let frozenFrame = take.analysisFrame

        XCTAssertEqual(frozenFrame.meters.lock.score.value, 0.4, accuracy: 0.0001)
        XCTAssertEqual(frozenFrame.meters.ring.score.value, 0.6, accuracy: 0.0001)
        XCTAssertEqual(frozenFrame.meters.roughness.score.value, 0.5, accuracy: 0.0001)
        XCTAssertEqual(frozenFrame.meters.stability.score.value, 0.75, accuracy: 0.0001)
        XCTAssertEqual(frozenFrame.timestamp, take.endedAt)
    }

    func testRecordedTakeFindsNearestFrameForScrubTime() {
        let take = take(
            slot: .takeA,
            duration: 2,
            frames: [
                frame(time: 0, lock: 0.2, ring: 0.2, roughness: 0.2, stability: 0.2),
                frame(time: 0.9, lock: 0.6, ring: 0.6, roughness: 0.2, stability: 0.6),
                frame(time: 1.8, lock: 0.9, ring: 0.9, roughness: 0.2, stability: 0.9)
            ]
        )

        XCTAssertEqual(take.frame(at: 1.0)?.meters.lock.score.value, 0.6)
        XCTAssertEqual(take.frame(at: 2.0)?.meters.lock.score.value, 0.9)
    }

    func testTakeRegionValidationAndClamping() {
        let invalid = TakeRegion(startTime: 2, endTime: 1)
        let overflowing = TakeRegion(name: "Tag", startTime: -1, endTime: 12)

        XCTAssertFalse(invalid.isValid)
        XCTAssertNil(invalid.clamped(to: 10))
        XCTAssertEqual(
            overflowing.clamped(to: 10),
            TakeRegion(id: overflowing.id, name: "Tag", startTime: 0, endTime: 10)
        )
    }

    func testScopedTakeUsesSelectedRegionFrames() {
        let region = TakeRegion(name: "Middle", startTime: 0.8, endTime: 1.4)
        let take = take(
            slot: .takeA,
            duration: 2,
            frames: [
                frame(time: 0, lock: 0.2, ring: 0.2, roughness: 0.2, stability: 0.2),
                frame(time: 1.0, lock: 0.7, ring: 0.7, roughness: 0.2, stability: 0.7),
                frame(time: 1.8, lock: 0.9, ring: 0.9, roughness: 0.2, stability: 0.9)
            ]
        )

        let scoped = take.scoped(to: region)

        XCTAssertEqual(scoped.name, "Middle")
        XCTAssertEqual(scoped.duration, 0.6, accuracy: 0.0001)
        XCTAssertEqual(scoped.frames.count, 1)
        XCTAssertEqual(scoped.summary.averageLock, 0.7, accuracy: 0.0001)
    }

    func testPlaybackStateReportsProgress() {
        let state = TakePlaybackState(
            duration: 10,
            currentTime: 2.5,
            isPlaying: true,
            isAvailable: true
        )

        XCTAssertEqual(state.progress, 0.25, accuracy: 0.0001)
    }

    func testPlaybackStateReportsLoopRange() {
        let state = TakePlaybackState(
            duration: 10,
            currentTime: 3,
            isPlaying: true,
            isAvailable: true,
            isLooping: true,
            rangeStart: 2,
            rangeEnd: 5
        )

        XCTAssertTrue(state.isLooping)
        XCTAssertEqual(state.rangeStart, 2)
        XCTAssertEqual(state.rangeEnd, 5)
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
        time: TimeInterval? = nil,
        lock: Double,
        ring: Double,
        roughness: Double,
        stability: Double
    ) -> AnalysisFrame {
        let frame = AnalysisFrame.placeholder.replacingMeters(
            MeterSnapshot(
                lock: snapshot(kind: .lock, score: lock),
                ring: snapshot(kind: .ring, score: ring),
                roughness: snapshot(kind: .roughness, score: roughness),
                stability: snapshot(kind: .stability, score: stability)
            )
        )

        guard let time else {
            return frame
        }

        return frame.replacingTimestamp(Date(timeIntervalSince1970: 100 + time))
    }

    private func snapshot(kind: MetricKind, score: Double) -> MetricSnapshot {
        MetricSnapshot(
            kind: kind,
            score: MetricScore(value: score),
            confidence: MetricConfidence(value: 1, reason: "fixture")
        )
    }

    private func audioInputFrame(samples: [Float]) -> AudioInputFrame {
        guard let frame = AudioFrameNormalizer.makeFrame(
            channels: [samples],
            sampleRate: 44_100
        ) else {
            XCTFail("Expected fixture audio frame")
            return AudioInputFrame(
                hostTime: 0,
                sampleRate: 44_100,
                frameSize: 0,
                channelCount: 0,
                monoSamples: [],
                channelSamples: [],
                instrumentation: AudioInputInstrumentation(
                    rmsLevel: 0,
                    channelRMSLevels: [],
                    isClipping: false,
                    channelClipping: [],
                    hasChannelImbalance: false,
                    noiseFloor: 0,
                    hasSignal: false
                )
            )
        }

        return frame
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

    func replacingTimestamp(_ timestamp: Date) -> AnalysisFrame {
        AnalysisFrame(
            timestamp: timestamp,
            meters: meters,
            spectrum: spectrum,
            spectrogram: spectrogram,
            ringHistory: ringHistory
        )
    }
}
