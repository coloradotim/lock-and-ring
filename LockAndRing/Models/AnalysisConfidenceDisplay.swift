import Foundation

enum AnalysisConfidenceState: Equatable, Sendable {
    case reliable
    case lowConfidence(reason: ConfidenceReason)
    case unavailable(reason: UnavailableReason)

    init(meters: MeterSnapshot, reliableThreshold: Double = 0.55) {
        let signalQuality = meters.dominantSignalQuality

        if signalQuality == .unavailable {
            self = .unavailable(reason: .noAnalysis)
            return
        }

        if let reason = ConfidenceReason(signalQuality: signalQuality) {
            self = .lowConfidence(reason: reason)
            return
        }

        if meters.averageConfidence < reliableThreshold {
            self = .lowConfidence(reason: .insufficientAnalyzableAudio)
            return
        }

        self = .reliable
    }

    var isReliable: Bool {
        self == .reliable
    }
}

enum ConfidenceReason: Equatable, Sendable {
    case signalTooQuiet
    case clipping
    case noisyInput
    case unstableSignal
    case insufficientAnalyzableAudio
    case channelImbalance

    init?(signalQuality: SignalQualityState) {
        switch signalQuality {
        case .nominal:
            return nil
        case .lowSignal:
            self = .signalTooQuiet
        case .clipping:
            self = .clipping
        case .noisy:
            self = .noisyInput
        case .unstable:
            self = .unstableSignal
        case .imbalanced:
            self = .channelImbalance
        case .unavailable:
            self = .insufficientAnalyzableAudio
        }
    }

    var shortLabel: String {
        switch self {
        case .signalTooQuiet:
            "Signal too quiet"
        case .clipping:
            "Input clipping"
        case .noisyInput:
            "Noisy input"
        case .unstableSignal:
            "Unstable signal"
        case .insufficientAnalyzableAudio:
            "Low confidence"
        case .channelImbalance:
            "Check mic placement"
        }
    }

    var explanation: String {
        switch self {
        case .signalTooQuiet:
            "the signal was too quiet"
        case .clipping:
            "the input clipped"
        case .noisyInput:
            "the input was noisy"
        case .unstableSignal:
            "the signal was unstable"
        case .insufficientAnalyzableAudio:
            "there was not enough analyzable audio"
        case .channelImbalance:
            "the microphone or channel balance looked uneven"
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .signalTooQuiet:
            "Move closer or sing louder."
        case .clipping:
            "Reduce input level or move back."
        case .noisyInput:
            "Reduce room noise or move closer."
        case .unstableSignal:
            "Try again with a steadier sung tone."
        case .insufficientAnalyzableAudio:
            "Record a little more sustained sound."
        case .channelImbalance:
            "Check microphone placement."
        }
    }
}

enum UnavailableReason: Equatable, Sendable {
    case noAnalysis
    case noTake

    var shortLabel: String {
        switch self {
        case .noAnalysis:
            "No analysis yet"
        case .noTake:
            "No take yet"
        }
    }

    var explanation: String {
        switch self {
        case .noAnalysis:
            "No analysis is available yet."
        case .noTake:
            "Record or import a take first."
        }
    }
}

struct AnalysisConfidenceDisplayState: Equatable, Sendable {
    let state: AnalysisConfidenceState
    let title: String
    let message: String

    init(state: AnalysisConfidenceState) {
        self.state = state

        switch state {
        case .reliable:
            self.title = "Reliable analysis"
            self.message = "Results are reliable enough for rehearsal feedback."
        case let .lowConfidence(reason):
            self.title = reason.shortLabel
            self.message = "Analysis may be unreliable because \(reason.explanation). \(reason.recoverySuggestion)"
        case let .unavailable(reason):
            self.title = reason.shortLabel
            self.message = reason.explanation
        }
    }
}

struct TakeAnalysisDisplayState: Equatable, Sendable {
    let confidenceState: AnalysisConfidenceState
    let warningMessage: String?
    let lockSummary: String

    init(take: RecordedTake, lockThreshold: Double = 0.75) {
        guard !take.frames.isEmpty else {
            self.confidenceState = .unavailable(reason: .noAnalysis)
            self.warningMessage = AnalysisConfidenceDisplayState(state: confidenceState).message
            self.lockSummary = "Record or import a take before evaluating lock."
            return
        }

        let meters = MeterSnapshot.aggregate(from: take.frames.map(\.meters))
        let confidenceState = AnalysisConfidenceState(meters: meters)
        let bestLock = take.frames
            .map { frame in
                (score: frame.meters.lock.score.value, time: frame.timestamp.timeIntervalSince(take.startedAt))
            }
            .max { $0.score < $1.score }
        let bestLockText = bestLock.map {
            let score = $0.score.formatted(.percent.precision(.fractionLength(0)))
            let time = $0.time.formatted(.number.precision(.fractionLength(2)))
            return "Best lock: \(score) at \(time)s."
        } ?? "Best lock unavailable."

        self.confidenceState = confidenceState
        self.warningMessage = confidenceState.isReliable
            ? nil
            : AnalysisConfidenceDisplayState(state: confidenceState).message

        if confidenceState.isReliable {
            self.lockSummary = (bestLock?.score ?? 0) >= lockThreshold
                ? "This take locked. \(bestLockText)"
                : "This take did not lock. \(bestLockText)"
        } else if case let .lowConfidence(reason) = confidenceState {
            self.lockSummary = """
            Could not reliably evaluate lock because \(reason.explanation). \(bestLockText) Confidence was low.
            """
        } else {
            self.lockSummary = "Could not evaluate lock. \(bestLockText)"
        }
    }
}

struct ChordTimingDisplayState: Equatable, Sendable {
    let confidenceState: AnalysisConfidenceState
    let warningMessage: String?
    let lockSummary: String

    init(analysis: ChordLabAnalysis) {
        self.confidenceState = analysis.confidenceState
        self.warningMessage = analysis.confidenceState.isReliable
            ? nil
            : AnalysisConfidenceDisplayState(state: analysis.confidenceState).message

        if analysis.confidenceState.isReliable {
            if analysis.summary.didLock {
                self.lockSummary = "Locked during the chord."
            } else {
                self.lockSummary = Self.bestLockText(prefix: "This chord did not lock.", summary: analysis.summary)
            }
        } else if case let .lowConfidence(reason) = analysis.confidenceState {
            self.lockSummary = Self.bestLockText(
                prefix: "Could not reliably evaluate lock because \(reason.explanation).",
                summary: analysis.summary
            )
        } else {
            self.lockSummary = "Could not evaluate chord timing yet."
        }
    }

    private static func bestLockText(prefix: String, summary: ChordTimingSummary) -> String {
        guard let score = summary.bestLockScore, let time = summary.bestLockTime else {
            return prefix
        }

        let formattedScore = score.formatted(.percent.precision(.fractionLength(0)))
        let formattedTime = time.formatted(.number.precision(.fractionLength(2)))

        return "\(prefix) Best lock: \(formattedScore) at \(formattedTime)s."
    }
}

struct PhraseSegmentationDisplayState: Equatable, Sendable {
    let confidenceState: AnalysisConfidenceState
    let warningMessage: String?
    let summary: String

    init(regionStates: [AnalysisConfidenceState]) {
        if regionStates.isEmpty {
            self.confidenceState = .unavailable(reason: .noAnalysis)
            self.warningMessage = "Some regions could not be classified because there was not enough analyzable audio."
            self.summary = "Phrase segmentation is not available for this take yet."
            return
        }

        if let lowConfidence = regionStates.first(where: { !$0.isReliable }) {
            self.confidenceState = lowConfidence
            self.warningMessage = "Some regions could not be classified because the signal was too quiet or unstable."
            self.summary = "Phrase timing is uncertain for this take."
            return
        }

        self.confidenceState = .reliable
        self.warningMessage = nil
        self.summary = "Phrase segmentation will appear here as phrase modules become available."
    }
}

extension MeterSnapshot {
    var dominantSignalQuality: SignalQualityState {
        let states = MetricKind.displayOrder.map { metric(for: $0).signalQuality }
        if let firstProblem = states.first(where: { $0 != .nominal }) {
            return firstProblem
        }

        return .nominal
    }

    static func aggregate(from snapshots: [MeterSnapshot]) -> MeterSnapshot {
        guard !snapshots.isEmpty else {
            return AnalysisFrame.placeholder.meters
        }

        return MeterSnapshot(
            lock: aggregateMetric(kind: .lock, snapshots: snapshots),
            ring: aggregateMetric(kind: .ring, snapshots: snapshots),
            roughness: aggregateMetric(kind: .roughness, snapshots: snapshots),
            stability: aggregateMetric(kind: .stability, snapshots: snapshots)
        )
    }

    private static func aggregateMetric(kind: MetricKind, snapshots: [MeterSnapshot]) -> MetricSnapshot {
        let metrics = snapshots.map { $0.metric(for: kind) }
        let averageScore = metrics.map(\.score.value).averageValue
        let averageConfidence = metrics.map(\.confidence.value).averageValue
        let signalQuality = metrics.map(\.signalQuality).first { $0 != .nominal } ?? .nominal

        return MetricSnapshot(
            kind: kind,
            score: MetricScore(value: averageScore),
            confidence: MetricConfidence(value: averageConfidence, reason: "Take average confidence."),
            signalQuality: signalQuality
        )
    }
}

private extension Array where Element == Double {
    var averageValue: Double {
        guard !isEmpty else {
            return 0
        }

        return reduce(0, +) / Double(count)
    }
}
