import Foundation

struct CompositeAnalysisScorer {
    private let spectrumAnalyzer: SpectrumAnalyzer
    private let roughnessScorer: RoughnessScorer
    private let ringScorer: RingScorer
    private let lockScorer: LockScorer
    private var stabilityScorer: StabilityScorer
    private var signalQualityAnalyzer: SignalQualityAnalyzer

    init(
        spectrumAnalyzer: SpectrumAnalyzer = SpectrumAnalyzer(),
        roughnessScorer: RoughnessScorer = RoughnessScorer(),
        ringScorer: RingScorer = RingScorer(),
        lockScorer: LockScorer = LockScorer(),
        stabilityScorer: StabilityScorer = StabilityScorer(),
        signalQualityAnalyzer: SignalQualityAnalyzer = SignalQualityAnalyzer()
    ) {
        self.spectrumAnalyzer = spectrumAnalyzer
        self.roughnessScorer = roughnessScorer
        self.ringScorer = ringScorer
        self.lockScorer = lockScorer
        self.stabilityScorer = stabilityScorer
        self.signalQualityAnalyzer = signalQualityAnalyzer
    }

    mutating func score(frame: AudioInputFrame) -> CompositeAnalysisResult {
        let spectrum = spectrumAnalyzer.analyze(
            samples: frame.monoSamples,
            sampleRate: frame.sampleRate
        )
        let roughness = roughnessScorer.score(spectrum: spectrum)
        let ring = ringScorer.score(spectrum: spectrum)
        let stability = stabilityScorer.score(spectrum: spectrum)
        let lock = lockScorer.score(
            spectrum: spectrum,
            roughness: roughness,
            stability: stability
        )
        let signalQuality = signalQualityAnalyzer.analyze(frame: frame, spectrum: spectrum)
        let meters = MeterSnapshot(
            lock: lock.metricSnapshot(),
            ring: ring.metricSnapshot(),
            roughness: roughness.metricSnapshot(),
            stability: stability.metricSnapshot()
        )
        .applyingSignalQuality(signalQuality)

        return CompositeAnalysisResult(
            spectrum: spectrum,
            meters: meters,
            ring: ring,
            roughness: roughness,
            lock: lock,
            stability: stability,
            signalQuality: signalQuality
        )
    }
}

struct CompositeAnalysisResult: Equatable {
    let spectrum: SpectrumSnapshot
    let meters: MeterSnapshot
    let ring: RingScore
    let roughness: RoughnessScore
    let lock: LockScore
    let stability: StabilityScore
    let signalQuality: SignalQualityAssessment
}
