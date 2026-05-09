import Foundation

struct PhraseSegmentationAnalysis: Equatable, Sendable {
    let summary: PhraseSegmentationSummary
    let timelineSegments: [PhraseTimelineSegment]
    let metricSeries: [PhraseMetricSeries]
    let confidenceState: AnalysisConfidenceState

    static let empty = PhraseSegmentationAnalysis(
        summary: PhraseSegmentationSummary(durations: [:]),
        timelineSegments: [],
        metricSeries: [],
        confidenceState: .unavailable(reason: .noAnalysis)
    )
}

struct PhraseSegmentationSummary: Equatable, Sendable {
    let phraseDuration: TimeInterval
    let consonantOnsetTime: TimeInterval
    let analyzableVowelTime: TimeInterval
    let lockedVowelTime: TimeInterval
    let ringingVowelTime: TimeInterval
    let tuningSearchingTime: TimeInterval
    let stableButNotRingingTime: TimeInterval
    let silenceBreathTime: TimeInterval
    let lowConfidenceTime: TimeInterval
    let transitionTime: TimeInterval

    init(durations: [PhraseTimelineSegmentKind: TimeInterval]) {
        self.consonantOnsetTime = durations[.consonantOrOnset, default: 0]
        self.lockedVowelTime = durations[.locked, default: 0]
        self.ringingVowelTime = durations[.ringing, default: 0]
        self.tuningSearchingTime = durations[.tuningOrSearching, default: 0]
        self.stableButNotRingingTime = durations[.stableButNotRinging, default: 0]
        self.silenceBreathTime = durations[.silenceOrBreath, default: 0]
        self.lowConfidenceTime = durations[.lowConfidence, default: 0]
        self.transitionTime = durations[.transition, default: 0]
        self.phraseDuration = durations.values.reduce(0, +)
        self.analyzableVowelTime = lockedVowelTime
            + ringingVowelTime
            + tuningSearchingTime
            + stableButNotRingingTime
            + transitionTime
    }

    var lockedVowelRatio: Double {
        ratio(lockedVowelTime)
    }

    var ringingVowelRatio: Double {
        ratio(ringingVowelTime)
    }

    private func ratio(_ value: TimeInterval) -> Double {
        guard analyzableVowelTime > 0 else {
            return 0
        }

        return value / analyzableVowelTime
    }
}

struct PhraseTimelineSegment: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: PhraseTimelineSegmentKind
    let startTime: TimeInterval
    let endTime: TimeInterval

    init(
        id: UUID = UUID(),
        kind: PhraseTimelineSegmentKind,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) {
        self.id = id
        self.kind = kind
        self.startTime = startTime
        self.endTime = max(endTime, startTime)
    }

    var duration: TimeInterval {
        endTime - startTime
    }
}

enum PhraseTimelineSegmentKind: String, Equatable, Hashable, Sendable {
    case silenceOrBreath
    case lowConfidence
    case consonantOrOnset
    case transition
    case tuningOrSearching
    case stableButNotRinging
    case locked
    case ringing

    var title: String {
        switch self {
        case .silenceOrBreath:
            "Silence / breath"
        case .lowConfidence:
            "Low confidence"
        case .consonantOrOnset:
            "Consonant / onset"
        case .transition:
            "Transition"
        case .tuningOrSearching:
            "Tuning / searching"
        case .stableButNotRinging:
            "Stable, not ringing"
        case .locked:
            "Locked"
        case .ringing:
            "Ringing"
        }
    }

    static let legendOrder: [PhraseTimelineSegmentKind] = [
        .silenceOrBreath,
        .lowConfidence,
        .consonantOrOnset,
        .transition,
        .tuningOrSearching,
        .stableButNotRinging,
        .locked,
        .ringing
    ]
}

struct PhraseMetricSeries: Identifiable, Equatable, Sendable {
    let id: MetricKind
    let kind: MetricKind
    let points: [TimelineMetricPoint]

    init(kind: MetricKind, frames: [AnalysisFrame], firstDate: Date) {
        self.id = kind
        self.kind = kind
        self.points = frames.map { frame in
            TimelineMetricPoint(
                time: frame.timestamp.timeIntervalSince(firstDate),
                value: frame.meters.metric(for: kind).score.value
            )
        }
    }
}

struct PhraseSegmenter {
    let configuration: AnalysisConfiguration

    init(configuration: AnalysisConfiguration = .default) {
        self.configuration = configuration
    }

    func analyze(frames: [AnalysisFrame]) -> PhraseSegmentationAnalysis {
        guard let firstDate = frames.first?.timestamp else {
            return .empty
        }

        let chordAnalysis = ChordLabAnalyzer(thresholds: configuration.chordTiming)
            .analyze(frames: frames)
        let segments = timelineSegments(
            for: frames,
            firstDate: firstDate,
            vowelStartTime: chordAnalysis.summary.analyzableVowelStartTime
        )
        let durations = Dictionary(grouping: segments, by: \.kind)
            .mapValues { $0.map(\.duration).reduce(0, +) }

        return PhraseSegmentationAnalysis(
            summary: PhraseSegmentationSummary(durations: durations),
            timelineSegments: segments,
            metricSeries: MetricKind.displayOrder.map {
                PhraseMetricSeries(kind: $0, frames: frames, firstDate: firstDate)
            },
            confidenceState: AnalysisConfidenceState(
                meters: MeterSnapshot.aggregate(from: frames.map(\.meters)),
                thresholds: configuration.confidence
            )
        )
    }

    private func timelineSegments(
        for frames: [AnalysisFrame],
        firstDate: Date,
        vowelStartTime: TimeInterval?
    ) -> [PhraseTimelineSegment] {
        let rawSegments = frames.enumerated().map { index, frame in
            let time = frame.timestamp.timeIntervalSince(firstDate)
            return PhraseTimelineSegment(
                kind: segmentKind(for: frame, time: time, vowelStartTime: vowelStartTime),
                startTime: time,
                endTime: time + frameDuration(at: index, frames: frames, firstDate: firstDate)
            )
        }

        return rawSegments.reduce(into: []) { result, segment in
            guard let last = result.last, last.kind == segment.kind else {
                result.append(segment)
                return
            }

            result[result.count - 1] = PhraseTimelineSegment(
                kind: last.kind,
                startTime: last.startTime,
                endTime: segment.endTime
            )
        }
    }

    private func segmentKind(
        for frame: AnalysisFrame,
        time: TimeInterval,
        vowelStartTime: TimeInterval?
    ) -> PhraseTimelineSegmentKind {
        let chord = configuration.chordTiming
        let confidence = frame.meters.averageConfidence
        let signalQuality = frame.meters.dominantSignalQuality

        if signalQuality == .unavailable || confidence < chord.soundOnsetConfidence {
            return .silenceOrBreath
        }

        if signalQuality != .nominal || confidence < chord.minimumMetricConfidence {
            return .lowConfidence
        }

        if let vowelStartTime, time < vowelStartTime {
            return .consonantOrOnset
        }

        if let vowelStartTime, time < vowelStartTime + chord.minimumSustainedDuration {
            return .transition
        }

        if isRinging(frame) {
            return .ringing
        }

        if isLocked(frame) {
            return .locked
        }

        if isStable(frame) {
            return .stableButNotRinging
        }

        return .tuningOrSearching
    }

    private func isRinging(_ frame: AnalysisFrame) -> Bool {
        let chord = configuration.chordTiming
        return frame.meters.ring.score.value >= chord.ringScore
            && frame.meters.ring.confidence.value >= chord.minimumMetricConfidence
            && frame.meters.roughness.score.value <= chord.maximumRoughnessForRing
    }

    private func isLocked(_ frame: AnalysisFrame) -> Bool {
        let chord = configuration.chordTiming
        return frame.meters.lock.score.value >= chord.lockScore
            && frame.meters.lock.confidence.value >= chord.minimumMetricConfidence
            && frame.meters.stability.score.value >= chord.minimumStabilityForLock
            && frame.meters.roughness.score.value <= chord.maximumRoughnessForLock
    }

    private func isStable(_ frame: AnalysisFrame) -> Bool {
        let chord = configuration.chordTiming
        return frame.meters.stability.score.value >= chord.stabilityScore
            && frame.meters.roughness.score.value <= chord.maximumRoughnessForLock
    }

    private func frameDuration(at index: Int, frames: [AnalysisFrame], firstDate: Date) -> TimeInterval {
        guard index + 1 < frames.count else {
            if index > 0 {
                return frames[index].timestamp.timeIntervalSince(frames[index - 1].timestamp)
            }

            return 0
        }

        return frames[index + 1].timestamp.timeIntervalSince(frames[index].timestamp)
    }
}
