@testable import LockAndRing
import XCTest

final class TakeTimelineComparisonTests: XCTestCase {
    func testAlignsByDetectedOnset() {
        let reference = take(.init(start: 10, onsetOffset: 0.2, lockOffset: 0.5, ringOffset: 0.7))
        let current = take(.init(start: 20, onsetOffset: 0.4, lockOffset: 0.6, ringOffset: 0.8))
        let comparison = TakeTimelineComparison(reference: reference, current: current)

        XCTAssertEqual(comparison.alignment.referenceOffset, 0.2, accuracy: 0.001)
        XCTAssertEqual(comparison.alignment.currentOffset, 0.4, accuracy: 0.001)
        XCTAssertNil(comparison.alignment.warning)
        XCTAssertFalse(comparison.reference.metricSeries.first?.points.isEmpty ?? true)
        XCTAssertTrue(comparison.displayModes.contains(.sideBySide))
        XCTAssertTrue(comparison.displayModes.contains(.overlay))
    }

    func testFallsBackWhenOnsetIsUnavailable() {
        let reference = take(.init(start: 10, onsetOffset: nil, lockOffset: nil, ringOffset: nil))
        let current = take(.init(start: 20, onsetOffset: 0.2, lockOffset: nil, ringOffset: nil))
        let comparison = TakeTimelineComparison(reference: reference, current: current)

        XCTAssertEqual(comparison.alignment.referenceOffset, 0)
        XCTAssertEqual(comparison.alignment.currentOffset, 0)
        XCTAssertEqual(
            comparison.alignment.warning,
            "Could not confidently align by onset; showing takes from recording start."
        )
    }

    func testSummaryReportsFasterLockAndMixedRingRatio() {
        let reference = take(.init(start: 10, onsetOffset: 0.1, lockOffset: 0.7, ringOffset: 0.8))
        let current = take(.init(start: 20, onsetOffset: 0.1, lockOffset: 0.4, ringOffset: nil))
        let comparison = TakeTimelineComparison(reference: reference, current: current)

        XCTAssertTrue(comparison.summaryLines.contains { $0.contains("lock") && $0.contains("faster") })
        XCTAssertTrue(comparison.summaryLines.contains { $0.contains("Ringing vowel ratio decreased") })
    }

    func testLowConfidenceWarningPropagates() {
        let reference = take(.init(start: 10, onsetOffset: 0.1, lockOffset: nil, ringOffset: nil))
        let current = take(.init(start: 20, onsetOffset: 0.1, lockOffset: nil, ringOffset: nil, confidence: 0.2))
        let comparison = TakeTimelineComparison(reference: reference, current: current)

        XCTAssertEqual(
            comparison.warning,
            "Comparison may be unreliable because one take had low signal confidence."
        )
    }

    private func take(_ fixture: TakeFixture) -> RecordedTake {
        let startedAt = Date(timeIntervalSince1970: fixture.start)
        let frames = stride(from: 0.0, through: 0.9, by: 0.1).map { offset in
            frame(
                date: startedAt.addingTimeInterval(offset),
                offset: offset,
                fixture: fixture
            )
        }

        return RecordedTake(
            slot: .takeA,
            name: "Fixture",
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(1),
            frames: frames
        )
    }

    private func frame(
        date: Date,
        offset: TimeInterval,
        fixture: TakeFixture
    ) -> AnalysisFrame {
        let hasSignal = fixture.onsetOffset.map { offset >= $0 } ?? false
        let locked = fixture.lockOffset.map { offset >= $0 } ?? false
        let ringing = fixture.ringOffset.map { offset >= $0 } ?? false
        let frameConfidence = hasSignal ? fixture.confidence : 0.05
        let signalQuality: SignalQualityState = frameConfidence >= 0.35 ? .nominal : .lowSignal

        return AnalysisFrame(
            timestamp: date,
            meters: MeterSnapshot(
                lock: snapshot(
                    kind: .lock,
                    score: locked ? 0.8 : 0.2,
                    confidence: frameConfidence,
                    signalQuality: signalQuality
                ),
                ring: snapshot(
                    kind: .ring,
                    score: ringing ? 0.6 : 0.1,
                    confidence: frameConfidence,
                    signalQuality: signalQuality
                ),
                roughness: snapshot(
                    kind: .roughness,
                    score: 0.2,
                    confidence: frameConfidence,
                    signalQuality: signalQuality
                ),
                stability: snapshot(
                    kind: .stability,
                    score: hasSignal ? 0.8 : 0.1,
                    confidence: frameConfidence,
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

    private struct TakeFixture {
        let start: TimeInterval
        let onsetOffset: TimeInterval?
        let lockOffset: TimeInterval?
        let ringOffset: TimeInterval?
        let confidence: Double

        init(
            start: TimeInterval,
            onsetOffset: TimeInterval?,
            lockOffset: TimeInterval?,
            ringOffset: TimeInterval?,
            confidence: Double = 0.8
        ) {
            self.start = start
            self.onsetOffset = onsetOffset
            self.lockOffset = lockOffset
            self.ringOffset = ringOffset
            self.confidence = confidence
        }
    }
}
