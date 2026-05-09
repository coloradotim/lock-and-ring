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
}
