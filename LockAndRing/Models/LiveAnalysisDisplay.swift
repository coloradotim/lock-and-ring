import Foundation

struct LiveAnalysisDisplayState: Equatable, Sendable {
    let meters: MeterSnapshot
    let history: [MeterSnapshot]
    let baseline: TakeSummary?

    var signal: SignalQualityDisplayState {
        SignalQualityDisplayState(meters: meters)
    }

    var metricStates: [MetricDisplayState] {
        [
            MetricDisplayState(snapshot: meters.lock),
            MetricDisplayState(snapshot: meters.ring),
            MetricDisplayState(snapshot: meters.roughness),
            MetricDisplayState(snapshot: meters.stability)
        ]
    }

    var trendSummary: TrendSummary {
        TrendSummary(history: history)
    }

    var baselineComparison: BaselineComparisonState {
        BaselineComparisonState(current: meters, baseline: baseline)
    }
}

struct SignalQualityDisplayState: Equatable, Sendable {
    let title: String
    let message: String
    let confidence: Double
    let isReliable: Bool

    init(meters: MeterSnapshot) {
        let state = meters.ring.signalQuality
        let confidence = meters.averageConfidence

        self.title = Self.title(for: state, confidence: confidence)
        self.message = Self.message(for: state, confidence: confidence)
        self.confidence = confidence
        self.isReliable = state == .nominal && confidence >= 0.55
    }

    private static func title(for state: SignalQualityState, confidence: Double) -> String {
        if state == .nominal && confidence >= 0.55 {
            return "Good signal"
        }

        return state.displayText
    }

    private static func message(for state: SignalQualityState, confidence: Double) -> String {
        switch state {
        case .nominal where confidence >= 0.55:
            return "Results are reliable enough for rehearsal feedback."
        case .lowSignal:
            return "Results unreliable. Move closer or sing louder."
        case .clipping:
            return "Results unreliable. Reduce input level or move back."
        case .noisy:
            return "Results uncertain. Reduce room noise or move closer."
        case .unstable:
            return "Results uncertain. Wait for a steadier sung tone."
        case .imbalanced:
            return "Results uncertain. Check microphone placement."
        case .unavailable:
            return "No signal detected yet."
        default:
            return "Results have limited confidence."
        }
    }
}

struct MetricDisplayState: Identifiable, Equatable, Sendable {
    let id: MetricKind
    let title: String
    let score: Double
    let confidence: Double
    let qualityLabel: String
    let isReliable: Bool

    init(snapshot: MetricSnapshot) {
        self.id = snapshot.kind
        self.title = snapshot.kind.displayTitle
        self.score = snapshot.score.value
        self.confidence = snapshot.confidence.value
        self.qualityLabel = Self.qualityLabel(for: snapshot)
        self.isReliable = snapshot.confidence.value >= 0.55 && snapshot.signalQuality == .nominal
    }

    private static func qualityLabel(for snapshot: MetricSnapshot) -> String {
        let value = snapshot.score.value

        switch snapshot.kind {
        case .lock:
            return label(value: value, bands: ["Searching", "Mostly aligned", "Locked"])
        case .ring:
            return label(value: value, bands: ["None", "Developing", "Present", "Strong"])
        case .roughness:
            return label(value: 1 - value, bands: ["Rough", "Some interference", "Smooth"])
        case .stability:
            return label(value: value, bands: ["Unstable", "Drifting", "Holding", "Stable"])
        }
    }

    private static func label(value: Double, bands: [String]) -> String {
        let clamped = min(max(value, 0), 1)
        let index = min(Int(clamped * Double(bands.count)), bands.count - 1)
        return bands[index]
    }
}

struct TrendSummary: Equatable, Sendable {
    let items: [MetricTrendItem]

    init(history: [MeterSnapshot]) {
        guard history.count >= 32 else {
            self.items = MetricKind.displayOrder.map {
                MetricTrendItem(kind: $0, direction: .notEnoughConfidence, delta: 0)
            }
            return
        }

        let recent = Array(history.suffix(16))
        let previous = Array(history.dropLast(16).suffix(16))

        self.items = MetricKind.displayOrder.map { kind in
            MetricTrendItem(kind: kind, recent: recent, previous: previous)
        }
    }
}

struct MetricTrendItem: Identifiable, Equatable, Sendable {
    enum Direction: Equatable, Sendable {
        case increased
        case decreased
        case unchanged
        case notEnoughConfidence
    }

    let id: MetricKind
    let kind: MetricKind
    let direction: Direction
    let delta: Double

    init(kind: MetricKind, direction: Direction, delta: Double) {
        self.id = kind
        self.kind = kind
        self.direction = direction
        self.delta = delta
    }

    init(kind: MetricKind, recent: [MeterSnapshot], previous: [MeterSnapshot]) {
        let recentConfidence = recent.map { $0.metric(for: kind).confidence.value }.average
        let previousConfidence = previous.map { $0.metric(for: kind).confidence.value }.average

        guard min(recentConfidence, previousConfidence) >= 0.35 else {
            self.init(kind: kind, direction: .notEnoughConfidence, delta: 0)
            return
        }

        let delta = recent.map { $0.metric(for: kind).score.value }.average
            - previous.map { $0.metric(for: kind).score.value }.average

        if abs(delta) < 0.03 {
            self.init(kind: kind, direction: .unchanged, delta: delta)
        } else {
            self.init(kind: kind, direction: delta > 0 ? .increased : .decreased, delta: delta)
        }
    }

    var summaryText: String {
        switch direction {
        case .increased:
            "\(kind.displayTitle) increased"
        case .decreased:
            "\(kind.displayTitle) decreased"
        case .unchanged:
            "\(kind.displayTitle) unchanged"
        case .notEnoughConfidence:
            "\(kind.displayTitle) not enough confidence"
        }
    }
}

struct BaselineComparisonState: Equatable, Sendable {
    let items: [BaselineComparisonItem]
    let hasBaseline: Bool

    init(current: MeterSnapshot, baseline: TakeSummary?) {
        guard let baseline else {
            self.items = []
            self.hasBaseline = false
            return
        }

        self.items = [
            BaselineComparisonItem(kind: .lock, current: current.lock.score.value, baseline: baseline.averageLock),
            BaselineComparisonItem(kind: .ring, current: current.ring.score.value, baseline: baseline.averageRing),
            BaselineComparisonItem(
                kind: .roughness,
                current: current.roughness.score.value,
                baseline: baseline.averageRoughness
            ),
            BaselineComparisonItem(
                kind: .stability,
                current: current.stability.score.value,
                baseline: baseline.averageStability
            )
        ]
        self.hasBaseline = true
    }
}

struct BaselineComparisonItem: Identifiable, Equatable, Sendable {
    let id: MetricKind
    let kind: MetricKind
    let improvement: Double

    init(kind: MetricKind, current: Double, baseline: Double) {
        self.id = kind
        self.kind = kind
        self.improvement = kind == .roughness ? baseline - current : current - baseline
    }

    var summaryText: String {
        if abs(improvement) < 0.01 {
            return "\(kind.displayTitle) unchanged"
        }

        let verb = improvement > 0 ? "improved" : "moved away"
        let value = abs(improvement).formatted(.percent.precision(.fractionLength(0)))
        return "\(kind.displayTitle) \(verb) \(value)"
    }
}

extension MeterSnapshot {
    var averageConfidence: Double {
        MetricKind.displayOrder
            .map { metric(for: $0).confidence.value }
            .average
    }

    func metric(for kind: MetricKind) -> MetricSnapshot {
        switch kind {
        case .lock:
            lock
        case .ring:
            ring
        case .roughness:
            roughness
        case .stability:
            stability
        }
    }
}

extension MetricKind {
    static let displayOrder: [MetricKind] = [.lock, .ring, .roughness, .stability]

    var displayTitle: String {
        switch self {
        case .lock:
            "Lock"
        case .ring:
            "Ring"
        case .roughness:
            "Roughness"
        case .stability:
            "Stability"
        }
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else {
            return 0
        }

        return reduce(0, +) / Double(count)
    }
}
