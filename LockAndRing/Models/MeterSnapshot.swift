import Foundation

struct MeterSnapshot: Equatable, Sendable {
    let lock: MetricScore
    let ring: MetricScore
    let roughness: MetricScore
    let stability: MetricScore

    func replacingRoughness(with value: Double) -> MeterSnapshot {
        MeterSnapshot(
            lock: lock,
            ring: ring,
            roughness: MetricScore(value: value),
            stability: stability
        )
    }

    func replacingRing(with value: Double) -> MeterSnapshot {
        MeterSnapshot(
            lock: lock,
            ring: MetricScore(value: value),
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
