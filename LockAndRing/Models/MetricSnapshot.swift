import Foundation

struct MetricSnapshot: Equatable, Sendable {
    let kind: MetricKind
    let score: MetricScore
    let confidence: MetricConfidence
    let contributingFactors: [MetricFactor]
    let rawMeasurements: [String: Double]
    let signalQuality: SignalQualityState
    let rollingAverage: MetricScore?

    init(
        kind: MetricKind,
        score: MetricScore,
        confidence: MetricConfidence,
        contributingFactors: [MetricFactor] = [],
        rawMeasurements: [String: Double] = [:],
        signalQuality: SignalQualityState = .nominal,
        rollingAverage: MetricScore? = nil
    ) {
        self.kind = kind
        self.score = score
        self.confidence = confidence
        self.contributingFactors = contributingFactors
        self.rawMeasurements = rawMeasurements
        self.signalQuality = signalQuality
        self.rollingAverage = rollingAverage
    }
}

enum MetricKind: String, Equatable, Sendable {
    case lock
    case ring
    case roughness
    case stability
}

struct MetricConfidence: Equatable, Sendable {
    let value: Double
    let reason: String

    init(value: Double, reason: String = "") {
        self.value = min(max(value, 0), 1)
        self.reason = reason
    }
}

struct MetricFactor: Equatable, Sendable {
    let name: String
    let value: Double
    let weight: Double

    init(name: String, value: Double, weight: Double = 1) {
        self.name = name
        self.value = min(max(value, 0), 1)
        self.weight = min(max(weight, 0), 1)
    }
}

enum SignalQualityState: Equatable, Sendable {
    case nominal
    case lowSignal
    case clipping
    case noisy
    case imbalanced
    case unavailable
}
