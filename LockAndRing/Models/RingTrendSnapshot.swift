import Foundation

struct RingTrendSnapshot: Equatable, Sendable {
    let scores: [RingScore]
    let maxCount: Int

    init(scores: [RingScore] = [], maxCount: Int = 80) {
        self.maxCount = maxCount
        self.scores = Array(scores.suffix(maxCount))
    }

    func appending(_ score: RingScore) -> RingTrendSnapshot {
        RingTrendSnapshot(scores: scores + [score], maxCount: maxCount)
    }

    static let placeholder = RingTrendSnapshot()
}
