import Foundation

enum TakeSlot: String, CaseIterable, Equatable, Sendable {
    case takeA
    case takeB

    var title: String {
        switch self {
        case .takeA:
            "Take 1"
        case .takeB:
            "Take 2"
        }
    }

    var defaultName: String {
        switch self {
        case .takeA:
            "Before adjustment"
        case .takeB:
            "After adjustment"
        }
    }
}

struct RecordedTake: Identifiable, Equatable, Sendable {
    let id: UUID
    let slot: TakeSlot
    let name: String
    let startedAt: Date
    let endedAt: Date
    let frames: [AnalysisFrame]

    init(
        id: UUID = UUID(),
        slot: TakeSlot,
        name: String,
        startedAt: Date,
        endedAt: Date,
        frames: [AnalysisFrame]
    ) {
        self.id = id
        self.slot = slot
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.frames = frames
    }

    var duration: TimeInterval {
        max(endedAt.timeIntervalSince(startedAt), 0)
    }

    var summary: TakeSummary {
        TakeSummary(take: self)
    }
}

struct TakeSummary: Equatable, Sendable {
    let slot: TakeSlot
    let name: String
    let frameCount: Int
    let duration: TimeInterval
    let averageLock: Double
    let averageRoughness: Double
    let averageRing: Double
    let averageStability: Double
    let averageConfidence: Double
    let stabilityDuration: TimeInterval

    init(take: RecordedTake, stableThreshold: Double = 0.65) {
        self.slot = take.slot
        self.name = take.name
        self.frameCount = take.frames.count
        self.duration = take.duration
        self.averageLock = Self.average(take.frames.map(\.meters.lock.score.value))
        self.averageRoughness = Self.average(take.frames.map(\.meters.roughness.score.value))
        self.averageRing = Self.average(take.frames.map(\.meters.ring.score.value))
        self.averageStability = Self.average(take.frames.map(\.meters.stability.score.value))
        self.averageConfidence = Self.average(take.frames.map(\.meters.averageConfidence))
        self.stabilityDuration = Self.stabilityDuration(
            frames: take.frames,
            duration: take.duration,
            stableThreshold: stableThreshold
        )
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else {
            return 0
        }

        return values.reduce(0, +) / Double(values.count)
    }

    private static func stabilityDuration(
        frames: [AnalysisFrame],
        duration: TimeInterval,
        stableThreshold: Double
    ) -> TimeInterval {
        guard !frames.isEmpty else {
            return 0
        }

        let stableFrames = frames.filter { $0.meters.stability.score.value >= stableThreshold }.count
        return duration * Double(stableFrames) / Double(frames.count)
    }
}

struct TakeComparisonSummary: Equatable, Sendable {
    let takeA: TakeSummary
    let takeB: TakeSummary
    let lock: MetricComparison
    let roughness: MetricComparison
    let ring: MetricComparison
    let stabilityDuration: MetricComparison

    init(takeA: RecordedTake, takeB: RecordedTake) {
        let summaryA = takeA.summary
        let summaryB = takeB.summary

        self.takeA = summaryA
        self.takeB = summaryB
        self.lock = MetricComparison(
            title: "Lock",
            takeA: summaryA.averageLock,
            takeB: summaryB.averageLock,
            higherIsBetter: true,
            unit: .percent
        )
        self.roughness = MetricComparison(
            title: "Roughness",
            takeA: summaryA.averageRoughness,
            takeB: summaryB.averageRoughness,
            higherIsBetter: false,
            unit: .percent
        )
        self.ring = MetricComparison(
            title: "Ring",
            takeA: summaryA.averageRing,
            takeB: summaryB.averageRing,
            higherIsBetter: true,
            unit: .percent
        )
        self.stabilityDuration = MetricComparison(
            title: "Stability",
            takeA: summaryA.stabilityDuration,
            takeB: summaryB.stabilityDuration,
            higherIsBetter: true,
            unit: .seconds
        )
    }

    var headline: String {
        if let confidenceWarning {
            return confidenceWarning
        }

        let improvedCount = comparisons.filter(\.isImproved).count
        let regressedCount = comparisons.filter(\.isRegressed).count

        if improvedCount > regressedCount {
            return "Take 2 improved"
        }

        if regressedCount > improvedCount {
            return "Take 2 moved away"
        }

        return "Take 2 was mixed"
    }

    var comparisons: [MetricComparison] {
        [lock, roughness, ring, stabilityDuration]
    }

    var confidenceWarning: String? {
        if min(takeA.averageConfidence, takeB.averageConfidence) < 0.55 {
            return "Comparison may be unreliable because one take had low signal confidence."
        }

        return nil
    }
}

struct MetricComparison: Equatable, Sendable {
    enum Unit: Equatable, Sendable {
        case percent
        case seconds
    }

    let title: String
    let takeA: Double
    let takeB: Double
    let higherIsBetter: Bool
    let unit: Unit

    var delta: Double {
        takeB - takeA
    }

    var improvement: Double {
        higherIsBetter ? delta : -delta
    }

    var isImproved: Bool {
        improvement > 0.01
    }

    var isRegressed: Bool {
        improvement < -0.01
    }

    var directionText: String {
        if isImproved {
            return higherIsBetter ? "up" : "down"
        }

        if isRegressed {
            return higherIsBetter ? "down" : "up"
        }

        return "steady"
    }
}

@MainActor
@Observable
final class TakeRecorder {
    private(set) var takeA: RecordedTake?
    private(set) var takeB: RecordedTake?
    private(set) var activeSlot: TakeSlot?
    private(set) var recordingStartedAt: Date?
    private(set) var recordingFrames: [AnalysisFrame] = []

    var comparison: TakeComparisonSummary? {
        guard let takeA, let takeB else {
            return nil
        }

        return TakeComparisonSummary(takeA: takeA, takeB: takeB)
    }

    var isRecording: Bool {
        activeSlot != nil
    }

    func take(for slot: TakeSlot) -> RecordedTake? {
        switch slot {
        case .takeA:
            takeA
        case .takeB:
            takeB
        }
    }

    func startRecording(slot: TakeSlot, now: Date = Date()) {
        activeSlot = slot
        recordingStartedAt = now
        recordingFrames = []
    }

    func record(_ frame: AnalysisFrame) {
        guard activeSlot != nil else {
            return
        }

        recordingFrames.append(frame)
    }

    func finishRecording(now: Date = Date()) {
        guard let activeSlot, let recordingStartedAt else {
            return
        }

        let take = RecordedTake(
            slot: activeSlot,
            name: activeSlot.defaultName,
            startedAt: recordingStartedAt,
            endedAt: now,
            frames: recordingFrames
        )
        set(take, for: activeSlot)
        self.activeSlot = nil
        self.recordingStartedAt = nil
        recordingFrames = []
    }

    func clear(slot: TakeSlot) {
        if activeSlot == slot {
            activeSlot = nil
            recordingStartedAt = nil
            recordingFrames = []
        }

        set(nil, for: slot)
    }

    private func set(_ take: RecordedTake?, for slot: TakeSlot) {
        switch slot {
        case .takeA:
            takeA = take
        case .takeB:
            takeB = take
        }
    }
}
