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
            lock: .placeholder(kind: .lock),
            ring: .placeholder(kind: .ring),
            roughness: .placeholder(kind: .roughness),
            stability: .placeholder(kind: .stability)
        ),
        spectrum: SpectrumSnapshot.placeholder,
        spectrogram: .placeholder,
        ringHistory: .placeholder
    )
}
