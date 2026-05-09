import Foundation

struct AnalysisFrame: Equatable, Sendable {
    let timestamp: Date
    let meters: MeterSnapshot
    let spectrum: SpectrumSnapshot
    let spectrogram: SpectrogramSnapshot
    let ringHistory: RingTrendSnapshot

    static let placeholder = AnalysisFrame(
        timestamp: Date(timeIntervalSince1970: 0),
        meters: MeterSnapshot(
            lock: MetricScore(value: 0),
            ring: MetricScore(value: 0),
            roughness: MetricScore(value: 0),
            stability: MetricScore(value: 0)
        ),
        spectrum: SpectrumSnapshot.placeholder,
        spectrogram: .placeholder,
        ringHistory: .placeholder
    )
}
