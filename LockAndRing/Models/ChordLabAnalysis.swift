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
        let bestLock = bestMetricPeak(in: samples, kind: .lock)
        let bestRing = bestMetricPeak(in: samples, kind: .ring)
        let heldLockDuration = duration(in: samples, matching: isLocked)
        let heldRingDuration = duration(in: samples, matching: isRinging)
        let summary = ChordTimingSummary(
            soundOnsetTime: soundOnset?.time,
            analyzableVowelStartTime: vowelStart?.time,
            consonantOnsetDuration: duration(from: soundOnset?.time, to: vowelStart?.time),
            timeFromVowelToStability: duration(from: vowelStart?.time, to: stability?.time),
            timeFromVowelToLock: duration(from: vowelStart?.time, to: lock?.time),
            timeFromVowelToRing: duration(from: vowelStart?.time, to: ring?.time),
            bestLockScore: bestLock?.score,
            bestLockTime: bestLock?.time,
            bestRingScore: bestRing?.score,
            bestRingTime: bestRing?.time,
            heldLockDuration: heldLockDuration,
            heldRingDuration: heldRingDuration,
            largestDelayContributor: largestDelayContributor(
                consonantDuration: duration(from: soundOnset?.time, to: vowelStart?.time),
                stabilityDuration: duration(from: vowelStart?.time, to: stability?.time),
                lockDuration: duration(from: vowelStart?.time, to: lock?.time),
                ringDuration: duration(from: lock?.time, to: ring?.time)
            )
        )

        return ChordLabAnalysis(
            summary: summary,
            timelineSegments: timelineSegments(for: samples, soundOnsetTime: soundOnset?.time, vowelStartTime: vowelStart?.time),
            eventMarkers: eventMarkers(
                soundOnset: soundOnset,
                vowelStart: vowelStart,
                lock: lock,
                ring: ring,
                bestLock: bestLock,
                bestRing: bestRing
            ),
            thresholds: thresholds
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

    private func bestMetricPeak(in samples: [ChordLabFrameSample], kind: MetricKind) -> ChordLabMetricPeak? {
        guard let sample = samples.max(by: {
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

    private func eventMarkers(
        soundOnset: ChordLabFrameSample?,
        vowelStart: ChordLabFrameSample?,
        lock: ChordLabFrameSample?,
        ring: ChordLabFrameSample?,
        bestLock: ChordLabMetricPeak?,
        bestRing: ChordLabMetricPeak?
    ) -> [ChordEventMarker] {
        [
            marker(kind: .soundOnset, time: soundOnset?.time),
            marker(kind: .analyzableVowelStart, time: vowelStart?.time),
            marker(kind: .lockAchieved, time: lock?.time),
            marker(kind: .ringAchieved, time: ring?.time),
            marker(kind: .bestLock, time: bestLock?.time),
            marker(kind: .bestRing, time: bestRing?.time)
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
    let thresholds: ChordLabThresholds

    static let empty = ChordLabAnalysis(
        summary: .empty,
        timelineSegments: [],
        eventMarkers: [],
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
            "Best lock"
        case .bestRing:
            "Best ring"
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
        minimumMetricConfidence: Double = 0.55,
        minimumSustainedDuration: TimeInterval = 0.15,
        stabilityScore: Double = 0.5,
        minimumStabilityForLock: Double = 0.5,
        lockScore: Double = 0.75,
        ringScore: Double = 0.6,
        maximumRoughnessForLock: Double = 0.5,
        maximumRoughnessForRing: Double = 0.5
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

private struct ChordLabFrameSample {
    let index: Int
    let time: TimeInterval
    let frame: AnalysisFrame

    var averageConfidence: Double {
        frame.meters.averageConfidence
    }
}
