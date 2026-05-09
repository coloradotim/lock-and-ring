import Foundation

struct MeterSnapshot: Equatable, Sendable {
    let lock: MetricSnapshot
    let ring: MetricSnapshot
    let roughness: MetricSnapshot
    let stability: MetricSnapshot

    func replacingRoughness(with value: Double) -> MeterSnapshot {
        replacingRoughness(with: roughness.replacingScore(value))
    }

    func replacingRoughness(with snapshot: MetricSnapshot) -> MeterSnapshot {
        MeterSnapshot(
            lock: lock,
            ring: ring,
            roughness: snapshot,
            stability: stability
        )
    }

    func replacingRing(with value: Double) -> MeterSnapshot {
        replacingRing(with: ring.replacingScore(value))
    }

    func replacingRing(with snapshot: MetricSnapshot) -> MeterSnapshot {
        MeterSnapshot(
            lock: lock,
            ring: snapshot,
            roughness: roughness,
            stability: stability
        )
    }

    func applyingSignalQuality(_ assessment: SignalQualityAssessment) -> MeterSnapshot {
        MeterSnapshot(
            lock: lock.applyingSignalQuality(assessment),
            ring: ring.applyingSignalQuality(assessment),
            roughness: roughness.applyingSignalQuality(assessment),
            stability: stability.applyingSignalQuality(assessment)
        )
    }
}

struct MetricScore: Equatable, Sendable {
    let value: Double

    init(value: Double) {
        self.value = min(max(value, 0), 1)
    }
}

extension MetricSnapshot {
    static func placeholder(kind: MetricKind) -> MetricSnapshot {
        MetricSnapshot(
            kind: kind,
            score: MetricScore(value: 0),
            confidence: MetricConfidence(value: 0, reason: "No analysis yet."),
            signalQuality: .unavailable
        )
    }

    func replacingScore(_ value: Double) -> MetricSnapshot {
        MetricSnapshot(
            kind: kind,
            score: MetricScore(value: value),
            confidence: confidence,
            contributingFactors: contributingFactors,
            rawMeasurements: rawMeasurements,
            signalQuality: signalQuality,
            rollingAverage: rollingAverage
        )
    }

    func applyingSignalQuality(_ assessment: SignalQualityAssessment) -> MetricSnapshot {
        MetricSnapshot(
            kind: kind,
            score: score,
            confidence: confidence.applyingSignalQuality(assessment),
            contributingFactors: contributingFactors + assessment.metricFactors,
            rawMeasurements: rawMeasurements.merging(assessment.rawMeasurements) { current, _ in current },
            signalQuality: assessment.state,
            rollingAverage: rollingAverage
        )
    }
}

extension MetricConfidence {
    func applyingSignalQuality(_ assessment: SignalQualityAssessment) -> MetricConfidence {
        let gatedValue = value * assessment.confidenceMultiplier
        let reason = [reason, assessment.displayText]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return MetricConfidence(value: gatedValue, reason: reason)
    }
}

extension SignalQualityAssessment {
    var metricFactors: [MetricFactor] {
        [
            MetricFactor(name: "Input level", value: levelAdequacy, weight: 0.3),
            MetricFactor(name: "SNR", value: signalToNoiseRatio, weight: 0.25),
            MetricFactor(name: "Spectral stability", value: spectralStability, weight: 0.25),
            MetricFactor(name: "Transient cleanliness", value: transientCleanliness, weight: 0.2)
        ]
    }

    var rawMeasurements: [String: Double] {
        [
            "signalQualityConfidence": confidenceMultiplier,
            "levelAdequacy": levelAdequacy,
            "signalToNoiseRatio": signalToNoiseRatio,
            "spectralStability": spectralStability,
            "transientCleanliness": transientCleanliness
        ]
    }
}
