import Foundation

struct AnalysisConfiguration: Equatable, Sendable {
    static let `default` = AnalysisConfiguration()

    let confidence: ConfidenceThresholds
    let chordTiming: ChordLabThresholds
    let trend: TrendThresholds
    let comparison: ComparisonThresholds

    init(
        confidence: ConfidenceThresholds = ConfidenceThresholds(),
        chordTiming: ChordLabThresholds = ChordLabThresholds(),
        trend: TrendThresholds = TrendThresholds(),
        comparison: ComparisonThresholds = ComparisonThresholds()
    ) {
        self.confidence = confidence
        self.chordTiming = chordTiming
        self.trend = trend
        self.comparison = comparison
    }

    var isValid: Bool {
        confidence.isValid
            && chordTiming.isValid
            && trend.isValid
            && comparison.isValid
    }
}

struct ConfidenceThresholds: Equatable, Sendable {
    let reliableAnalysis: Double
    let aggregateLowConfidenceFrame: Double
    let clippingFrameRatio: Double
    let problemFrameRatio: Double

    init(
        reliableAnalysis: Double = 0.55,
        aggregateLowConfidenceFrame: Double = 0.55,
        clippingFrameRatio: Double = 0.1,
        problemFrameRatio: Double = 0.33
    ) {
        self.reliableAnalysis = reliableAnalysis
        self.aggregateLowConfidenceFrame = aggregateLowConfidenceFrame
        self.clippingFrameRatio = clippingFrameRatio
        self.problemFrameRatio = problemFrameRatio
    }

    var isValid: Bool {
        reliableAnalysis.isUnitInterval
            && aggregateLowConfidenceFrame.isUnitInterval
            && clippingFrameRatio.isUnitInterval
            && problemFrameRatio.isUnitInterval
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

    var isValid: Bool {
        soundOnsetConfidence.isUnitInterval
            && analyzableConfidence.isUnitInterval
            && minimumMetricConfidence.isUnitInterval
            && minimumSustainedDuration >= 0
            && stabilityScore.isUnitInterval
            && minimumStabilityForLock.isUnitInterval
            && lockScore.isUnitInterval
            && ringScore.isUnitInterval
            && maximumRoughnessForLock.isUnitInterval
            && maximumRoughnessForRing.isUnitInterval
    }
}

struct TrendThresholds: Equatable, Sendable {
    let minimumConfidence: Double
    let meaningfulDelta: Double

    init(minimumConfidence: Double = 0.35, meaningfulDelta: Double = 0.03) {
        self.minimumConfidence = minimumConfidence
        self.meaningfulDelta = meaningfulDelta
    }

    var isValid: Bool {
        minimumConfidence.isUnitInterval && meaningfulDelta >= 0 && meaningfulDelta <= 1
    }
}

struct ComparisonThresholds: Equatable, Sendable {
    let stableFrameScore: Double
    let reliableTakeConfidence: Double
    let meaningfulDelta: Double

    init(
        stableFrameScore: Double = 0.65,
        reliableTakeConfidence: Double = 0.55,
        meaningfulDelta: Double = 0.01
    ) {
        self.stableFrameScore = stableFrameScore
        self.reliableTakeConfidence = reliableTakeConfidence
        self.meaningfulDelta = meaningfulDelta
    }

    var isValid: Bool {
        stableFrameScore.isUnitInterval
            && reliableTakeConfidence.isUnitInterval
            && meaningfulDelta >= 0
            && meaningfulDelta <= 1
    }
}

private extension Double {
    var isUnitInterval: Bool {
        self >= 0 && self <= 1
    }
}
