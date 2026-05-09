import Foundation

struct TakeTimelineComparison: Equatable, Sendable {
    enum DisplayMode: Equatable, Sendable {
        case sideBySide
        case overlay
    }

    let reference: AlignedTakeTimeline
    let current: AlignedTakeTimeline
    let alignment: TimelineAlignment
    let summaryLines: [String]
    let warning: String?

    init(reference: RecordedTake, current: RecordedTake) {
        let referenceChord = ChordLabAnalyzer().analyze(frames: reference.frames)
        let currentChord = ChordLabAnalyzer().analyze(frames: current.frames)
        let referencePhrase = PhraseSegmenter().analyze(frames: reference.frames)
        let currentPhrase = PhraseSegmenter().analyze(frames: current.frames)
        let alignment = TimelineAlignment(reference: referenceChord, current: currentChord)

        self.reference = AlignedTakeTimeline(
            take: reference,
            role: "Reference",
            alignmentOffset: alignment.referenceOffset,
            chordAnalysis: referenceChord,
            phraseAnalysis: referencePhrase
        )
        self.current = AlignedTakeTimeline(
            take: current,
            role: "Current",
            alignmentOffset: alignment.currentOffset,
            chordAnalysis: currentChord,
            phraseAnalysis: currentPhrase
        )
        self.alignment = alignment
        self.summaryLines = Self.summaryLines(
            referenceChord: referenceChord,
            currentChord: currentChord,
            referencePhrase: referencePhrase,
            currentPhrase: currentPhrase
        )
        self.warning = Self.warning(reference: reference, current: current, alignment: alignment)
    }

    var displayModes: [DisplayMode] {
        [.sideBySide, .overlay]
    }

    private static func summaryLines(
        referenceChord: ChordLabAnalysis,
        currentChord: ChordLabAnalysis,
        referencePhrase: PhraseSegmentationAnalysis,
        currentPhrase: PhraseSegmentationAnalysis
    ) -> [String] {
        [
            timingSummary(
                title: "lock",
                reference: referenceChord.summary.timeFromVowelToLock,
                current: currentChord.summary.timeFromVowelToLock
            ),
            timingSummary(
                title: "ring",
                reference: referenceChord.summary.timeFromVowelToRing,
                current: currentChord.summary.timeFromVowelToRing
            ),
            ratioSummary(
                title: "Locked vowel",
                reference: referencePhrase.summary.lockedVowelRatio,
                current: currentPhrase.summary.lockedVowelRatio
            ),
            ratioSummary(
                title: "Ringing vowel",
                reference: referencePhrase.summary.ringingVowelRatio,
                current: currentPhrase.summary.ringingVowelRatio
            )
        ].compactMap { $0 }
    }

    private static func timingSummary(title: String, reference: TimeInterval?, current: TimeInterval?) -> String? {
        guard let reference, let current else {
            return nil
        }

        let delta = reference - current
        guard abs(delta) >= AnalysisConfiguration.default.comparison.meaningfulDelta else {
            return "This take reached \(title) at about the same time."
        }

        let direction = delta > 0 ? "faster" : "slower"
        return "This take reached \(title) \(formatSeconds(abs(delta))) \(direction)."
    }

    private static func ratioSummary(title: String, reference: Double, current: Double) -> String? {
        let delta = current - reference
        guard abs(delta) >= AnalysisConfiguration.default.comparison.meaningfulDelta else {
            return "\(title) time was about the same."
        }

        let direction = delta > 0 ? "improved" : "decreased"
        return "\(title) ratio \(direction) by \(formatPercent(abs(delta)))."
    }

    private static func warning(
        reference: RecordedTake,
        current: RecordedTake,
        alignment: TimelineAlignment
    ) -> String? {
        if min(reference.summary.averageConfidence, current.summary.averageConfidence)
            < AnalysisConfiguration.default.comparison.reliableTakeConfidence {
            return "Comparison may be unreliable because one take had low signal confidence."
        }

        return alignment.warning
    }

    private static func formatSeconds(_ value: TimeInterval) -> String {
        value.formatted(.number.precision(.fractionLength(1))) + "s"
    }

    private static func formatPercent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}

struct AlignedTakeTimeline: Equatable, Sendable {
    let take: RecordedTake
    let role: String
    let alignmentOffset: TimeInterval
    let chordAnalysis: ChordLabAnalysis
    let phraseAnalysis: PhraseSegmentationAnalysis

    var metricSeries: [TimelineMetricSeries] {
        MetricKind.displayOrder.map { kind in
            TimelineMetricSeries(
                kind: kind,
                points: take.frames.map { frame in
                    TimelineMetricPoint(
                        time: frame.timestamp.timeIntervalSince(take.startedAt) - alignmentOffset,
                        value: frame.meters.metric(for: kind).score.value
                    )
                }
            )
        }
    }

    var markers: [TimelineMarker] {
        chordAnalysis.eventMarkers.map {
            TimelineMarker(title: $0.kind.title, time: $0.time - alignmentOffset)
        }
    }
}

struct TimelineAlignment: Equatable, Sendable {
    let referenceOffset: TimeInterval
    let currentOffset: TimeInterval
    let warning: String?

    init(reference: ChordLabAnalysis, current: ChordLabAnalysis) {
        if let referenceOnset = reference.summary.soundOnsetTime,
           let currentOnset = current.summary.soundOnsetTime {
            self.referenceOffset = referenceOnset
            self.currentOffset = currentOnset
            self.warning = nil
        } else {
            self.referenceOffset = 0
            self.currentOffset = 0
            self.warning = "Could not confidently align by onset; showing takes from recording start."
        }
    }
}

struct TimelineMarker: Identifiable, Equatable, Sendable {
    let id = UUID()
    let title: String
    let time: TimeInterval
}

struct TimelineMetricPoint: Equatable, Sendable {
    let time: TimeInterval
    let value: Double
}

struct TimelineMetricSeries: Identifiable, Equatable, Sendable {
    let id: MetricKind
    let kind: MetricKind
    let points: [TimelineMetricPoint]

    init(kind: MetricKind, points: [TimelineMetricPoint]) {
        self.id = kind
        self.kind = kind
        self.points = points
    }
}
