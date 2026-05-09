import Foundation

struct ChordLabEventSamples {
    let soundOnset: ChordLabFrameSample?
    let vowelStart: ChordLabFrameSample?
    let stability: ChordLabFrameSample?
    let lock: ChordLabFrameSample?
    let ring: ChordLabFrameSample?
    let bestLock: ChordLabMetricPeak?
    let bestRing: ChordLabMetricPeak?
}

struct ChordLabFrameSample {
    let index: Int
    let time: TimeInterval
    let frame: AnalysisFrame

    var averageConfidence: Double {
        frame.meters.averageConfidence
    }
}
