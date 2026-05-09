@testable import LockAndRing
import XCTest

final class LiveAnalysisDisplayTests: XCTestCase {
    func testSignalStatusReportsReliableGoodSignal() {
        let state = SignalQualityDisplayState(meters: meters(confidence: 0.8, signalQuality: .nominal))

        XCTAssertEqual(state.title, "Good signal")
        XCTAssertTrue(state.isReliable)
    }

    func testSignalStatusWarnsForLowConfidence() {
        let state = SignalQualityDisplayState(meters: meters(confidence: 0.3, signalQuality: .lowSignal))

        XCTAssertEqual(state.title, "Signal too quiet")
        XCTAssertFalse(state.isReliable)
        XCTAssertTrue(state.message.contains("Results unreliable"))
    }

    func testMetricDisplayLabelsUseSingerFriendlyLanguage() {
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .lock, score: 0.72)).qualityLabel, "Mostly aligned")
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .ring, score: 0.4)).qualityLabel, "Developing")
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .roughness, score: 0.12)).qualityLabel, "Smooth")
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .stability, score: 0.62)).qualityLabel, "Holding")
    }

    func testMetricDisplayLabelThresholdBoundaries() {
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .lock, score: 0.19)).qualityLabel, "Not aligned")
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .lock, score: 0.2)).qualityLabel, "Searching")
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .lock, score: 0.5)).qualityLabel, "Mostly aligned")
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .lock, score: 0.75)).qualityLabel, "Locked")
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .ring, score: 0.49)).qualityLabel, "Developing")
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .ring, score: 0.5)).qualityLabel, "Present")
        XCTAssertEqual(
            MetricDisplayState(snapshot: snapshot(kind: .roughness, score: 0.8)).qualityLabel,
            "Highly unstable"
        )
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .stability, score: 0.74)).qualityLabel, "Holding")
        XCTAssertEqual(MetricDisplayState(snapshot: snapshot(kind: .stability, score: 0.75)).qualityLabel, "Stable")
    }

    func testMetricDisplayLabelsAreOverriddenByLowConfidenceSignalStates() {
        let lowConfidence = MetricDisplayState(
            snapshot: snapshot(kind: .lock, score: 0.9, confidence: 0.2)
        )
        let lowSignal = MetricDisplayState(
            snapshot: snapshot(kind: .ring, score: 0.9, signalQuality: .lowSignal)
        )
        let clipping = MetricDisplayState(
            snapshot: snapshot(kind: .stability, score: 0.9, signalQuality: .clipping)
        )

        XCTAssertEqual(lowConfidence.qualityLabel, "Low confidence")
        XCTAssertEqual(lowSignal.qualityLabel, "Signal too quiet")
        XCTAssertEqual(clipping.qualityLabel, "Input clipping")
    }

    func testTrendSummaryComparesRecentWindowToPreviousWindow() {
        let previous = Array(repeating: meters(ring: 0.2, roughness: 0.7), count: 16)
        let recent = Array(repeating: meters(ring: 0.6, roughness: 0.3), count: 16)

        let summary = TrendSummary(history: previous + recent)

        XCTAssertEqual(summary.items.first { $0.kind == .ring }?.direction, .increased)
        XCTAssertEqual(summary.items.first { $0.kind == .roughness }?.direction, .decreased)
    }

    func testTrendSummaryAvoidsLowConfidenceClaims() {
        let history = Array(
            repeating: meters(ring: 0.6, roughness: 0.3, confidence: 0.2),
            count: 32
        )

        let summary = TrendSummary(history: history)

        XCTAssertEqual(summary.items.first?.direction, .notEnoughConfidence)
        XCTAssertFalse(summary.hasUsableChanges)
        XCTAssertEqual(
            summary.lowConfidenceMessage,
            "Not enough usable signal to evaluate changes yet. Move closer or sing louder."
        )
    }

    func testBaselineComparisonTreatsLowerRoughnessAsImprovement() {
        let baseline = takeSummary(
            lock: 0.4,
            ring: 0.3,
            roughness: 0.6,
            stability: 0.2
        )
        let comparison = BaselineComparisonState(
            current: meters(lock: 0.5, ring: 0.4, roughness: 0.4, stability: 0.2),
            baseline: baseline
        )

        XCTAssertTrue(comparison.hasBaseline)
        XCTAssertEqual(
            comparison.items.first { $0.kind == .roughness }?.summaryText,
            "Roughness improved 20%"
        )
    }

    func testSelectedModeControlsPrimaryWorkflow() {
        XCTAssertTrue(AppModeDisplayState(mode: .live).showsLiveRehearsalWorkflow)
        XCTAssertFalse(AppModeDisplayState(mode: .live).showsFullTakeWorkflow)
        XCTAssertFalse(AppModeDisplayState(mode: .live).showsFullFileWorkflow)
        XCTAssertTrue(AppModeDisplayState(mode: .takes).showsFullTakeWorkflow)
        XCTAssertTrue(AppModeDisplayState(mode: .file).showsFullFileWorkflow)
    }

    private func takeSummary(
        lock: Double,
        ring: Double,
        roughness: Double,
        stability: Double
    ) -> TakeSummary {
        let start = Date(timeIntervalSince1970: 0)
        let take = RecordedTake(
            slot: .takeA,
            name: "Baseline",
            startedAt: start,
            endedAt: start.addingTimeInterval(1),
            frames: [frame(lock: lock, ring: ring, roughness: roughness, stability: stability)]
        )

        return take.summary
    }

    private func frame(
        lock: Double,
        ring: Double,
        roughness: Double,
        stability: Double
    ) -> AnalysisFrame {
        AnalysisFrame(
            timestamp: Date(timeIntervalSince1970: 0),
            meters: meters(lock: lock, ring: ring, roughness: roughness, stability: stability),
            spectrum: .placeholder,
            spectrogram: .placeholder,
            ringHistory: .placeholder
        )
    }

    private func meters(
        lock: Double = 0.5,
        ring: Double = 0.5,
        roughness: Double = 0.5,
        stability: Double = 0.5,
        confidence: Double = 0.8,
        signalQuality: SignalQualityState = .nominal
    ) -> MeterSnapshot {
        MeterSnapshot(
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
        )
    }

    private func snapshot(
        kind: MetricKind,
        score: Double,
        confidence: Double = 0.8,
        signalQuality: SignalQualityState = .nominal
    ) -> MetricSnapshot {
        MetricSnapshot(
            kind: kind,
            score: MetricScore(value: score),
            confidence: MetricConfidence(value: confidence, reason: "fixture"),
            signalQuality: signalQuality
        )
    }
}
