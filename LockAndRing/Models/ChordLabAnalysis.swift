import Foundation

struct ChordLabAnalyzer {
    let thresholds: ChordLabThresholds

    init(thresholds: ChordLabThresholds = ChordLabThresholds()) {
        self.thresholds = thresholds
    }

    func analyze(frames: [AnalysisFrame]) -> ChordLabAnalysis {
        guard let firstDate = frames.first?.timestamp else {
            return ChordLabAnalysis.empty
        }

        let samples = frames.enumerated().map { index, frame in
            ChordLabFrameSample(
                index: index,
                time: frame.timestamp.timeIntervalSince(firstDate),
                frame: frame
            )
        }
        let soundOnset = samples.first { $0.averageConfidence >= thresholds.soundOnsetConfidence }
        let vowelStart = firstSustainedSample(in: samples, after: soundOnset?.time ?? 0) { sample in
            sample.averageConfidence >= thresholds.analyzableConfidence
                && sample.frame.meters.stability.confidence.value >= thresholds.minimumMetricConfidence
        }
        let stability = firstSustainedSample(in: samples, after: vowelStart?.time ?? 0) { sample in
            sample.frame.meters.stability.score.value >= thresholds.stabilityScore
                && sample.frame.meters.stability.confidence.value >= thresholds.minimumMetricConfidence
        }
        let lock = firstSustainedSample(in: samples, after: vowelStart?.time ?? 0, matching: isLocked)
        let ring = firstSustainedSample(in: samples, after: vowelStart?.time ?? 0, matching: isRinging)
        let bestLock = bestMetricPeak(in: samples, kind: .lock, startingAt: vowelStart?.time)
        let bestRing = bestMetricPeak(in: samples, kind: .ring, startingAt: vowelStart?.time)
        let events = ChordLabEventSamples(
            soundOnset: soundOnset,
            vowelStart: vowelStart,
            stability: stability,
            lock: lock,
            ring: ring,
            bestLock: bestLock,
            bestRing: bestRing
        )

        return ChordLabAnalysis(
            summary: timingSummary(for: events, in: samples),
            timelineSegments: timelineSegments(
                for: samples,
                soundOnsetTime: soundOnset?.time,
                vowelStartTime: vowelStart?.time
            ),
            eventMarkers: eventMarkers(for: events),
            confidenceState: AnalysisConfidenceState(
                meters: MeterSnapshot.aggregate(from: frames.map(\.meters))
            ),
            thresholds: thresholds
        )
    }

    private func timingSummary(
        for events: ChordLabEventSamples,
        in samples: [ChordLabFrameSample]
    ) -> ChordTimingSummary {
        let heldLockDuration = duration(in: samples, matching: isLocked)
        let heldRingDuration = duration(in: samples, matching: isRinging)

        return ChordTimingSummary(
            soundOnsetTime: events.soundOnset?.time,
            analyzableVowelStartTime: events.vowelStart?.time,
            consonantOnsetDuration: duration(from: events.soundOnset?.time, to: events.vowelStart?.time),
            timeFromVowelToStability: duration(from: events.vowelStart?.time, to: events.stability?.time),
            timeFromVowelToLock: duration(from: events.vowelStart?.time, to: events.lock?.time),
            timeFromVowelToRing: duration(from: events.vowelStart?.time, to: events.ring?.time),
            bestLockScore: events.bestLock?.score,
            bestLockTime: events.bestLock?.time,
            bestRingScore: events.bestRing?.score,
            bestRingTime: events.bestRing?.time,
            heldLockDuration: heldLockDuration,
            heldRingDuration: heldRingDuration,
            largestDelayContributor: largestDelayContributor(
                consonantDuration: duration(from: events.soundOnset?.time, to: events.vowelStart?.time),
                stabilityDuration: duration(from: events.vowelStart?.time, to: events.stability?.time),
                lockDuration: duration(from: events.vowelStart?.time, to: events.lock?.time),
                ringDuration: duration(from: events.lock?.time, to: events.ring?.time)
            )
        )
    }

    private func firstSustainedSample(
        in samples: [ChordLabFrameSample],
        after startTime: TimeInterval,
        matching predicate: (ChordLabFrameSample) -> Bool
    ) -> ChordLabFrameSample? {
        for sample in samples where sample.time >= startTime && predicate(sample) {
            let sustainedDuration = sustainedDuration(in: samples, startingAt: sample.index, matching: predicate)
            if sustainedDuration >= thresholds.minimumSustainedDuration {
                return sample
            }
        }

        return nil
    }

    private func isLocked(_ sample: ChordLabFrameSample) -> Bool {
        sample.frame.meters.lock.score.value >= thresholds.lockScore
            && sample.frame.meters.lock.confidence.value >= thresholds.minimumMetricConfidence
            && sample.frame.meters.stability.score.value >= thresholds.minimumStabilityForLock
            && sample.frame.meters.roughness.score.value <= thresholds.maximumRoughnessForLock
    }

    private func isRinging(_ sample: ChordLabFrameSample) -> Bool {
        sample.frame.meters.ring.score.value >= thresholds.ringScore
            && sample.frame.meters.ring.confidence.value >= thresholds.minimumMetricConfidence
            && sample.frame.meters.roughness.score.value <= thresholds.maximumRoughnessForRing
    }

    private func bestMetricPeak(
        in samples: [ChordLabFrameSample],
        kind: MetricKind,
        startingAt vowelStartTime: TimeInterval?
    ) -> ChordLabMetricPeak? {
        guard let vowelStartTime else {
            return nil
        }

        let eligibleSamples = samples.filter { sample in
            sample.time >= vowelStartTime
                && sample.averageConfidence >= thresholds.analyzableConfidence
                && sample.frame.meters.metric(for: kind).confidence.value >= thresholds.minimumMetricConfidence
        }

        guard let sample = eligibleSamples.max(by: {
            $0.frame.meters.metric(for: kind).score.value < $1.frame.meters.metric(for: kind).score.value
        }) else {
            return nil
        }

        return ChordLabMetricPeak(
            kind: kind,
            score: sample.frame.meters.metric(for: kind).score.value,
            time: sample.time
        )
    }

    private func timelineSegments(
        for samples: [ChordLabFrameSample],
        soundOnsetTime: TimeInterval?,
        vowelStartTime: TimeInterval?
    ) -> [ChordTimelineSegment] {
        guard !samples.isEmpty else {
            return []
        }

        let rawSegments = samples.enumerated().map { index, sample in
            ChordTimelineSegment(
                kind: segmentKind(for: sample, soundOnsetTime: soundOnsetTime, vowelStartTime: vowelStartTime),
                startTime: sample.time,
                endTime: sample.time + frameDuration(at: index, in: samples)
            )
        }

        return rawSegments.reduce(into: []) { result, segment in
            guard let last = result.last, last.kind == segment.kind else {
                result.append(segment)
                return
            }

            result[result.count - 1] = ChordTimelineSegment(
                kind: last.kind,
                startTime: last.startTime,
                endTime: segment.endTime
            )
        }
    }

    private func segmentKind(
        for sample: ChordLabFrameSample,
        soundOnsetTime: TimeInterval?,
        vowelStartTime: TimeInterval?
    ) -> ChordTimelineSegmentKind {
        if sample.averageConfidence < thresholds.soundOnsetConfidence {
            return .silence
        }

        guard let soundOnsetTime, sample.time >= soundOnsetTime else {
            return .silence
        }

        if sample.averageConfidence < thresholds.analyzableConfidence {
            return .lowConfidence
        }

        if let vowelStartTime, sample.time < vowelStartTime {
            return .consonantOrOnset
        }

        if isRinging(sample) {
            return .ringing
        }

        if isLocked(sample) {
            return .locked
        }

        if sample.frame.meters.stability.score.value >= thresholds.stabilityScore {
            return .stable
        }

        return .searching
    }

    private func eventMarkers(for events: ChordLabEventSamples) -> [ChordEventMarker] {
        [
            marker(kind: .soundOnset, time: events.soundOnset?.time),
            marker(kind: .analyzableVowelStart, time: events.vowelStart?.time),
            marker(kind: .lockAchieved, time: events.lock?.time),
            marker(kind: .ringAchieved, time: events.ring?.time),
            marker(kind: .bestLock, time: events.bestLock?.time),
            marker(kind: .bestRing, time: events.bestRing?.time)
        ].compactMap { $0 }
    }

    private func marker(kind: ChordEventMarkerKind, time: TimeInterval?) -> ChordEventMarker? {
        guard let time else {
            return nil
        }

        return ChordEventMarker(kind: kind, time: time)
    }

    private func duration(
        in samples: [ChordLabFrameSample],
        matching predicate: (ChordLabFrameSample) -> Bool
    ) -> TimeInterval {
        samples.enumerated().reduce(0) { total, item in
            let (index, sample) = item

            if predicate(sample) {
                return total + frameDuration(at: index, in: samples)
            }

            return total
        }
    }

    private func sustainedDuration(
        in samples: [ChordLabFrameSample],
        startingAt startIndex: Int,
        matching predicate: (ChordLabFrameSample) -> Bool
    ) -> TimeInterval {
        var total = 0.0

        for index in startIndex..<samples.count {
            guard predicate(samples[index]) else {
                break
            }

            total += frameDuration(at: index, in: samples)
        }

        return total
    }

    private func frameDuration(at index: Int, in samples: [ChordLabFrameSample]) -> TimeInterval {
        if samples.indices.contains(index + 1) {
            return max(samples[index + 1].time - samples[index].time, 0)
        }

        guard samples.count >= 2 else {
            return 0
        }

        return max(samples[index].time - samples[index - 1].time, 0)
    }

    private func duration(from start: TimeInterval?, to end: TimeInterval?) -> TimeInterval? {
        guard let start, let end, end >= start else {
            return nil
        }

        return end - start
    }

    private func largestDelayContributor(
        consonantDuration: TimeInterval?,
        stabilityDuration: TimeInterval?,
        lockDuration: TimeInterval?,
        ringDuration: TimeInterval?
    ) -> ChordDelayContributor {
        [
            (ChordDelayContributor.consonantOrOnset, consonantDuration),
            (.stability, stabilityDuration),
            (.lock, lockDuration),
            (.ring, ringDuration)
        ]
        .compactMap { contributor, duration in duration.map { (contributor, $0) } }
        .max { $0.1 < $1.1 }?
        .0 ?? .none
    }
}

struct ChordLabAnalysis: Equatable, Sendable {
    let summary: ChordTimingSummary
    let timelineSegments: [ChordTimelineSegment]
    let eventMarkers: [ChordEventMarker]
    let confidenceState: AnalysisConfidenceState
    let thresholds: ChordLabThresholds

    static let empty = ChordLabAnalysis(
        summary: .empty,
        timelineSegments: [],
        eventMarkers: [],
        confidenceState: .unavailable(reason: .noAnalysis),
        thresholds: ChordLabThresholds()
    )
}

struct ChordTimingSummary: Equatable, Sendable {
    let soundOnsetTime: TimeInterval?
    let analyzableVowelStartTime: TimeInterval?
    let consonantOnsetDuration: TimeInterval?
    let timeFromVowelToStability: TimeInterval?
    let timeFromVowelToLock: TimeInterval?
    let timeFromVowelToRing: TimeInterval?
    let bestLockScore: Double?
    let bestLockTime: TimeInterval?
    let bestRingScore: Double?
    let bestRingTime: TimeInterval?
    let heldLockDuration: TimeInterval
    let heldRingDuration: TimeInterval
    let largestDelayContributor: ChordDelayContributor

    static let empty = ChordTimingSummary(
        soundOnsetTime: nil,
        analyzableVowelStartTime: nil,
        consonantOnsetDuration: nil,
        timeFromVowelToStability: nil,
        timeFromVowelToLock: nil,
        timeFromVowelToRing: nil,
        bestLockScore: nil,
        bestLockTime: nil,
        bestRingScore: nil,
        bestRingTime: nil,
        heldLockDuration: 0,
        heldRingDuration: 0,
        largestDelayContributor: .none
    )

    var didLock: Bool {
        timeFromVowelToLock != nil
    }

    var didRing: Bool {
        timeFromVowelToRing != nil
    }
}

struct ChordTimelineSegment: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: ChordTimelineSegmentKind
    let startTime: TimeInterval
    let endTime: TimeInterval

    init(
        id: UUID = UUID(),
        kind: ChordTimelineSegmentKind,
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

enum ChordTimelineSegmentKind: String, Equatable, Sendable {
    case silence
    case consonantOrOnset
    case searching
    case stable
    case locked
    case ringing
    case lowConfidence

    var title: String {
        switch self {
        case .silence:
            "Silence"
        case .consonantOrOnset:
            "Consonant / onset"
        case .searching:
            "Searching"
        case .stable:
            "Stable"
        case .locked:
            "Locked"
        case .ringing:
            "Ringing"
        case .lowConfidence:
            "Low confidence"
        }
    }

    var paletteToken: ChordTimelinePaletteToken {
        switch self {
        case .silence:
            .neutralGray
        case .consonantOrOnset:
            .orange
        case .searching:
            .amber
        case .stable:
            .blue
        case .locked:
            .green
        case .ringing:
            .purple
        case .lowConfidence:
            .red
        }
    }
}

enum ChordTimelinePaletteToken: Equatable, Hashable, Sendable {
    case neutralGray
    case orange
    case amber
    case blue
    case green
    case purple
    case red
}

extension ChordTimelineSegmentKind {
    static let legendOrder: [ChordTimelineSegmentKind] = [
        .silence,
        .consonantOrOnset,
        .searching,
        .stable,
        .locked,
        .ringing,
        .lowConfidence
    ]
}

struct ChordEventMarker: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: ChordEventMarkerKind
    let time: TimeInterval

    init(id: UUID = UUID(), kind: ChordEventMarkerKind, time: TimeInterval) {
        self.id = id
        self.kind = kind
        self.time = time
    }
}

enum ChordEventMarkerKind: String, Equatable, Sendable {
    case soundOnset
    case analyzableVowelStart
    case lockAchieved
    case ringAchieved
    case bestLock
    case bestRing

    var title: String {
        switch self {
        case .soundOnset:
            "Sound onset"
        case .analyzableVowelStart:
            "Vowel start"
        case .lockAchieved:
            "Lock"
        case .ringAchieved:
            "Ring"
        case .bestLock:
            "Best locked vowel"
        case .bestRing:
            "Best ringing vowel"
        }
    }
}

struct ChordLabMetricPeak: Equatable, Sendable {
    let kind: MetricKind
    let score: Double
    let time: TimeInterval
}

enum ChordDelayContributor: Equatable, Sendable {
    case consonantOrOnset
    case stability
    case lock
    case ring
    case none

    var title: String {
        switch self {
        case .consonantOrOnset:
            "consonant/onset"
        case .stability:
            "stability"
        case .lock:
            "lock"
        case .ring:
            "ring"
        case .none:
            "none detected"
        }
    }
}

struct ChordLabThresholds: Equatable, Sendable {
    let soundOnsetConfidence: Double
    let analyzableConfidence: Double
    let minimumMetricConfidence: Double
    let minimumSustainedDuration: TimeInterval
    let stabilityScore: Double
    let minimumStabilityForLock: Double
    let lockScore: Double
    let ringScore: Double
    let maximumRoughnessForLock: Double
    let maximumRoughnessForRing: Double

    init(
        soundOnsetConfidence: Double = 0.15,
        analyzableConfidence: Double = 0.35,
        minimumMetricConfidence: Double = 0.45,
        minimumSustainedDuration: TimeInterval = 0.15,
        stabilityScore: Double = 0.5,
        minimumStabilityForLock: Double = 0.4,
        lockScore: Double = 0.65,
        ringScore: Double = 0.45,
        maximumRoughnessForLock: Double = 0.65,
        maximumRoughnessForRing: Double = 0.7
    ) {
        self.soundOnsetConfidence = soundOnsetConfidence
        self.analyzableConfidence = analyzableConfidence
        self.minimumMetricConfidence = minimumMetricConfidence
        self.minimumSustainedDuration = minimumSustainedDuration
        self.stabilityScore = stabilityScore
        self.minimumStabilityForLock = minimumStabilityForLock
        self.lockScore = lockScore
        self.ringScore = ringScore
        self.maximumRoughnessForLock = maximumRoughnessForLock
        self.maximumRoughnessForRing = maximumRoughnessForRing
    }
}
