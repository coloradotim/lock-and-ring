import Foundation

struct MeterSnapshot: Equatable, Sendable {
    let lock: MetricScore
    let ring: MetricScore
    let roughness: MetricScore
    let stability: MetricScore
}

struct MetricScore: Equatable, Sendable {
    let value: Double

    init(value: Double) {
        self.value = min(max(value, 0), 1)
    }
}
