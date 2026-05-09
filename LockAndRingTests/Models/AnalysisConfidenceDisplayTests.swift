@testable import LockAndRing
import XCTest

final class AnalysisConfidenceDisplayTests: XCTestCase {
    func testConfidenceReasonsMapToDeterministicCopy() {
        let display = AnalysisConfidenceDisplayState(state: .lowConfidence(reason: .signalTooQuiet))

        XCTAssertEqual(display.title, "Signal too quiet")
        XCTAssertEqual(
            display.message,
            "Analysis may be unreliable because the signal was too quiet. Move closer or sing louder."
        )
    }

    func testClippedInputProducesReliabilityWarning() {
        let state = AnalysisConfidenceState(meters: meters(signalQuality: .clipping))
        let display = AnalysisConfidenceDisplayState(state: state)

        XCTAssertEqual(display.title, "Input clipping")
        XCTAssertTrue(display.message.contains("the input clipped"))
    }

    func testLowConfidenceLockSummaryDoesNotHardClaimDidNotLock() {
        let take = take(
            frames: [
                frame(time: 0, lock: 0.61, confidence: 0.2, signalQuality: .lowSignal),
                frame(time: 0.1, lock: 0.45, confidence: 0.2, signalQuality: .lowSignal)
            ]
        )
        let state = TakeAnalysisDisplayState(take: take)

        XCTAssertTrue(state.lockSummary.contains("Could not reliably evaluate lock"))
        XCTAssertFalse(state.lockSummary.contains("This take did not lock"))
        XCTAssertTrue(state.lockSummary.contains("Best lock: 61%"))
    }

    func testReliableLowLockTakeCanSayDidNotLock() {
        let take = take(
            frames: [
                frame(time: 0, lock: 0.61, confidence: 0.9),
                frame(time: 0.1, lock: 0.45, confidence: 0.9)
            ]
        )
        let state = TakeAnalysisDisplayState(take: take)

        XCTAssertEqual(state.lockSummary, "This take did not lock. Best lock: 61% at 0.00s.")
    }

    func testShortLowConfidenceRegionDoesNotForceGlobalLowConfidence() {
        let take = take(
            frames: [
                frame(time: 0, confidence: 0.9),
                frame(time: 0.1, confidence: 0.9),
                frame(time: 0.2, confidence: 0.2, signalQuality: .lowSignal),
                frame(time: 0.3, confidence: 0.9)
            ]
        )
        let state = TakeAnalysisDisplayState(take: take)

        XCTAssertEqual(state.confidenceState, .reliable)
        XCTAssertNil(state.warningMessage)
    }

    func testPersistentClippingProducesGlobalLowConfidenceReason() {
        let take = take(
            frames: [
                frame(time: 0, confidence: 0.9, signalQuality: .clipping),
                frame(time: 0.1, confidence: 0.9, signalQuality: .clipping),
                frame(time: 0.2, confidence: 0.9),
                frame(time: 0.3, confidence: 0.9)
            ]
        )
        let state = TakeAnalysisDisplayState(take: take)

        XCTAssertEqual(state.confidenceState, .lowConfidence(reason: .clipping))
        XCTAssertTrue(state.warningMessage?.contains("input clipped") == true)
    }

    func testLowConfidenceComparisonProducesWarning() {
        let comparison = TakeComparisonSummary(
            takeA: take(frames: [frame(time: 0, confidence: 0.9)]),
            takeB: take(frames: [frame(time: 0, confidence: 0.2, signalQuality: .lowSignal)])
        )

        XCTAssertEqual(
            comparison.confidenceWarning,
            "Comparison may be unreliable because one take had low signal confidence."
        )
        XCTAssertEqual(comparison.headline, comparison.confidenceWarning)
    }

    func testLowConfidenceChordTimingAvoidsDidNotLockClaim() {
        let analysis = ChordLabAnalyzer(
            thresholds: ChordLabThresholds(minimumSustainedDuration: 0.1)
        )
        .analyze(
            frames: [
                frame(time: 0, lock: 0.61, confidence: 0.2, signalQuality: .lowSignal),
                frame(time: 0.1, lock: 0.52, confidence: 0.2, signalQuality: .lowSignal)
            ]
        )
        let state = ChordTimingDisplayState(analysis: analysis)

        XCTAssertTrue(state.lockSummary.contains("Could not reliably evaluate lock"))
        XCTAssertFalse(state.lockSummary.contains("This chord did not lock"))
    }

    func testChordTimingSummaryNamesLockAndRingBehavior() {
        let state = ChordTimingDisplayState(
            analysis: chordAnalysis(
                summary: chordSummary(
                    timeFromVowelToLock: 0.22,
                    timeFromVowelToRing: 0.31,
                    largestDelayContributor: .ring
                )
            )
        )

        XCTAssertTrue(state.lockSummary.contains("locked quickly"))
        XCTAssertTrue(state.lockSummary.contains("developed ring quickly"))
        XCTAssertTrue(state.lockSummary.contains("Main delay: ring"))
    }

    func testChordTimingSummaryNamesLockWithoutStrongRing() {
        let state = ChordTimingDisplayState(
            analysis: chordAnalysis(
                summary: chordSummary(
                    timeFromVowelToLock: 0.42,
                    timeFromVowelToRing: nil,
                    bestRingScore: 0.51,
                    bestRingTime: 0.62
                )
            )
        )

        XCTAssertTrue(state.lockSummary.contains("locked after a brief search"))
        XCTAssertTrue(state.lockSummary.contains("did not develop strong ring"))
        XCTAssertTrue(state.lockSummary.contains("Best ring: 51% at 0.62s"))
    }

    func testChordTimingSummaryNamesNoLockWithBestAttempt() {
        let state = ChordTimingDisplayState(
            analysis: chordAnalysis(
                summary: chordSummary(
                    timeFromVowelToLock: nil,
                    timeFromVowelToRing: nil,
                    bestLockScore: 0.55,
                    bestRingScore: 0.32
                )
            )
        )

        XCTAssertTrue(state.lockSummary.contains("This chord did not lock"))
        XCTAssertTrue(state.lockSummary.contains("Best lock: 55% at 0.44s"))
    }

    func testChordTimingSummaryDoesNotDenyStrongShortMoments() {
        let state = ChordTimingDisplayState(
            analysis: chordAnalysis(
                summary: chordSummary(
                    timeFromVowelToLock: nil,
                    timeFromVowelToRing: nil,
                    bestLockScore: 0.7,
                    bestRingScore: 0.5
                )
            )
        )

        XCTAssertTrue(state.lockSummary.contains("had lock or ring moments"))
        XCTAssertFalse(state.lockSummary.contains("This chord did not lock"))
    }

    func testPhraseSegmentationReportsUncertaintyForInsufficientAudio() {
        let state = PhraseSegmentationDisplayState(regionStates: [.lowConfidence(reason: .signalTooQuiet)])

        XCTAssertEqual(
            state.warningMessage,
            "Some regions could not be classified because the signal was too quiet or unstable."
        )
    }

    private func chordAnalysis(
        summary: ChordTimingSummary,
        confidenceState: AnalysisConfidenceState = .reliable
    ) -> ChordLabAnalysis {
        ChordLabAnalysis(
            summary: summary,
            timelineSegments: [],
            eventMarkers: [],
            confidenceState: confidenceState,
            thresholds: ChordLabThresholds()
        )
    }

    private func chordSummary(
        timeFromVowelToLock: TimeInterval?,
        timeFromVowelToRing: TimeInterval?,
        bestLockScore: Double? = 0.66,
        bestRingScore: Double? = 0.58,
        bestRingTime: TimeInterval? = 0.55,
        largestDelayContributor: ChordDelayContributor = .lock
    ) -> ChordTimingSummary {
        ChordTimingSummary(
            soundOnsetTime: 0.1,
            analyzableVowelStartTime: 0.18,
            consonantOnsetDuration: 0.08,
            timeFromVowelToStability: 0.16,
            timeFromVowelToLock: timeFromVowelToLock,
            timeFromVowelToRing: timeFromVowelToRing,
            bestLockScore: bestLockScore,
            bestLockTime: 0.44,
            bestRingScore: bestRingScore,
            bestRingTime: bestRingTime,
            heldLockDuration: 0.34,
            heldRingDuration: timeFromVowelToRing == nil ? 0 : 0.24,
            largestDelayContributor: largestDelayContributor
        )
    }

    private func take(frames: [AnalysisFrame]) -> RecordedTake {
        RecordedTake(
            slot: .takeA,
            name: "Fixture",
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 1),
            frames: frames
        )
    }

    private func frame(
        time: TimeInterval,
        lock: Double = 0.5,
        ring: Double = 0.5,
        roughness: Double = 0.2,
        stability: Double = 0.7,
        confidence: Double = 0.8,
        signalQuality: SignalQualityState = .nominal
    ) -> AnalysisFrame {
        AnalysisFrame(
            timestamp: Date(timeIntervalSince1970: time),
            meters: meters(
                lock: lock,
                ring: ring,
                roughness: roughness,
                stability: stability,
                confidence: confidence,
                signalQuality: signalQuality
            ),
            spectrum: .placeholder,
            spectrogram: .placeholder,
            ringHistory: .placeholder
        )
    }

    private func meters(
        lock: Double = 0.5,
        ring: Double = 0.5,
        roughness: Double = 0.2,
        stability: Double = 0.7,
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
